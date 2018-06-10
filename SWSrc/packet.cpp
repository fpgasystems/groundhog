/* Packet driver routines
Revision History:
	Changed buffer implementation & allocation to be much faster - Ken Eguro, 10/23/09
	Cleared out old code - Ken Eguro, 10/23/09
*/
#include "include.h"

static ULONG *MyMacP;

void UnusedParameter(void *temp){

}

//=============================================================================
//  Function: PacketInit()
//
//  Description: Initialize a new PACKET object.
//=============================================================================
// Zero out the number of valid bytes available and flag it as invalid.

void
PacketInit( 
    PACKET * Packet
    )
{
	assert(Packet != NULL);
	Packet->completed = false;
	Packet->acked = false;
	
	Packet->nBytesAvail = 0;

#ifdef BIGDEBUG	
	printf("Resetting mode on packet @%x\n", Packet);
#endif
	Packet->Mode = PacketModeInvalid;
}

//=============================================================================
//  Function: PacketAllocate()
//
//  Description: Allocation of a new packet.
//=============================================================================

// First, determine if there are any allocated but unused packets in the FreePackets list.
// If there are any, point to one of those and update the FreePackets pointer
// If not, create a new packet and allocate space for the buffer.
// If our memory allocation fails, return with Packet == NULL
void
PacketAllocate( 
    PPACKET_DRIVER_STATE PacketDriver,
    PACKET ** Packet
    )
{
    *Packet = PacketDriver->FreePackets;

	if (*Packet != NULL){
		//We can reuse a packet that has already been allocated
        PacketDriver->FreePackets = (*Packet)->Next;
		(*Packet)->Next = NULL;
	}
	else{
		//We have to allocate a brand new packet
		*Packet = new PACKET;
		assert(*Packet != NULL);
		if(!*Packet){
			return;
		}

		memset(*Packet, 0, sizeof(PACKET));

		(*Packet)->Buffer = (uint8_t *) malloc(sizeof(uint8_t) * MAXPACKETSIZE);
		assert((*Packet)->Buffer);
		if(!(*Packet)->Buffer){
			delete *Packet;
			*Packet = NULL;
			return;
		}

		(*Packet)->Length = MAXPACKETSIZE;
        PacketInit(*Packet);
	}
}

//=============================================================================
//  Function: PacketFree()
//
//  Description: Return a packet to the free list.
//=============================================================================
// Mark the packet as having no valid bytes, invalid and put it in the list of free packets.
void
PacketFree( 
    PPACKET_DRIVER_STATE PacketDriver,
    PACKET * Packet
    )
{
	PacketInit(Packet);

    Packet->Next = PacketDriver->FreePackets;
    PacketDriver->FreePackets = Packet;
}

//=============================================================================
//  Function: PacketWriteFile()
//
//  Description: Write a packet using NT WriteFile(). 
//=============================================================================

HRESULT
PacketWriteFile(    
    IN HANDLE hFile,
    IN PACKET * Packet
    )
{
    HRESULT Result = S_OK;
    BOOL    bResult = FALSE;
    DWORD   nBytesTransferred = 0;

    //
    //  Call NT WriteFile().
    //

    Packet->Result = ERROR_IO_PENDING;

	assert(Packet->Mode == PacketModeTransmitting);
    
	bResult = WriteFile(
                    hFile, 
                    Packet->Buffer, 
                    Packet->nBytesAvail, 
                    &nBytesTransferred, 
                    &Packet->Overlapped
                    );
    
    //
    //  If the read request completed immediately,
    //  complete the pending request now.
    //

    if ( bResult != FALSE )
    {
        Packet->Result = S_OK;

        return S_OK;
    }
    
    //
    //  The read request returned FALSE, check to see if its pending.
    //

    Result = GetLastError();

    if ( Result == ERROR_IO_PENDING ) 
    {
        return Result;
    } 

    //
    //  Check for EOF. 
    //

    if ( Result == ERROR_HANDLE_EOF ) 
    {
        assert(nBytesTransferred == 0);


        return S_FALSE;
    } 

    return Result;
}

//=============================================================================
//  Function: PacketReadFile()
//
//  Description: Read (post) a packet using NT ReadFile(). 
//=============================================================================

HRESULT
PacketReadFile( 
    HANDLE hFile,
    PACKET * Packet
    )
{
    HRESULT Result = S_OK;
    BOOL    bResult = FALSE;
    DWORD   nBytesTransferred = 0;

    //
    //  Call NT ReadFile().
    //

    Packet->nBytesAvail = 0;
    Packet->Result = ERROR_IO_PENDING;

	assert(Packet->Mode == PacketModeInvalid);
	Packet->Mode = PacketModeReceiving;

    bResult = ReadFile(
                    hFile, 
                    Packet->Buffer, 
                    Packet->Length, 
                    &nBytesTransferred, 
                    &Packet->Overlapped
                    );
    
    //
    //  If the read request completed immediately,
    //  complete the pending request now.
    //
    if ( bResult != FALSE )
    {
        Packet->nBytesAvail = nBytesTransferred;
        Packet->Result = S_OK;

        return S_OK;
    }
    
    //
    //  The read request returned FALSE, check to see if its pending.
    //
    Result = GetLastError();

    if ( Result == ERROR_IO_PENDING ) 
    {
        return Result;
    } 

    //
    //  Check for EOF. 
    //
    if ( Result == ERROR_HANDLE_EOF ) 
    {
        assert(nBytesTransferred == 0);

        return S_FALSE;
    } 

    return Result;
}

//=============================================================================
//    SubSection: VirtualpcDriver::
//
//    Description: VirtualPC's shared-use NDIS filter driver
//=============================================================================

#define NETSV_DRIVER_NAME					L"\\\\.\\VPCNetS2"

#define	kVPCNetSvVersionMajor	2
#define	kVPCNetSvVersionMinor	6
#define	kVPCNetSvVersion		((kVPCNetSvVersionMajor << 16) | kVPCNetSvVersionMinor)

#define FILE_DEVICE_PROTOCOL				0x8000

enum
{
	kIoctlFunction_SetOid					 = 0,
	kIoctlFunction_QueryOid,
	kIoctlFunction_Reset,
	kIoctlFunction_EnumAdapters,
	kIoctlFunction_GetStatistics,
	kIoctlFunction_GetVersion,
	kIoctlFunction_GetFeatures,
	kIoctlFunction_SendToHostOnly,
	kIoctlFunction_RegisterGuest,
	kIoctlFunction_DeregisterGuest,
	kIoctlFunction_CreateVirtualAdapter,
	kIoctlFunction_DestroyVirtualAdapter,
	kIoctlFunction_GetAdapterAttributes,
	kIoctlFunction_Bogus					 = 0xFFF
};

// These IOCTLs apply only to the control object
#if 0
#define IOCTL_ENUM_ADAPTERS					CTL_CODE(FILE_DEVICE_PROTOCOL, kIoctlFunction_EnumAdapters,				METHOD_BUFFERED, FILE_ANY_ACCESS)
#endif
#define IOCTL_GET_VERSION					CTL_CODE(FILE_DEVICE_PROTOCOL, kIoctlFunction_GetVersion,				METHOD_BUFFERED, FILE_ANY_ACCESS)
#define IOCTL_GET_FEATURES					CTL_CODE(FILE_DEVICE_PROTOCOL, kIoctlFunction_GetFeatures,				METHOD_BUFFERED, FILE_ANY_ACCESS)

// These IOCTLs apply only to the adapter object
#if 0
#define IOCTL_PROTOCOL_RESET				CTL_CODE(FILE_DEVICE_PROTOCOL, kIoctlFunction_Reset,					METHOD_BUFFERED, FILE_ANY_ACCESS)
#endif
#define IOCTL_CREATE_VIRTUAL_ADAPTER		CTL_CODE(FILE_DEVICE_PROTOCOL, kIoctlFunction_CreateVirtualAdapter,		METHOD_BUFFERED, FILE_ANY_ACCESS)
#define IOCTL_DESTROY_VIRTUAL_ADAPTER		CTL_CODE(FILE_DEVICE_PROTOCOL, kIoctlFunction_DestroyVirtualAdapter,	METHOD_BUFFERED, FILE_ANY_ACCESS)

#define IOCTL_GET_ADAPTER_ATTRIBUTES		CTL_CODE(FILE_DEVICE_PROTOCOL, kIoctlFunction_GetAdapterAttributes,		METHOD_BUFFERED, FILE_ANY_ACCESS)

// These IOCTLs apply only to the virtual adapter object
#if 0
#define IOCTL_PROTOCOL_SET_OID				CTL_CODE(FILE_DEVICE_PROTOCOL, kIoctlFunction_SetOid,					METHOD_BUFFERED, FILE_ANY_ACCESS)
#define IOCTL_PROTOCOL_QUERY_OID			CTL_CODE(FILE_DEVICE_PROTOCOL, kIoctlFunction_QueryOid,					METHOD_BUFFERED, FILE_ANY_ACCESS)
#endif
#define IOCTL_SEND_TO_HOST_ONLY				CTL_CODE(FILE_DEVICE_PROTOCOL, kIoctlFunction_SendToHostOnly,			METHOD_IN_DIRECT, FILE_ANY_ACCESS)

#define IOCTL_REGISTER_GUEST				CTL_CODE(FILE_DEVICE_PROTOCOL, kIoctlFunction_RegisterGuest,			METHOD_BUFFERED, FILE_ANY_ACCESS)
#define IOCTL_DEREGISTER_GUEST				CTL_CODE(FILE_DEVICE_PROTOCOL, kIoctlFunction_DeregisterGuest,			METHOD_BUFFERED, FILE_ANY_ACCESS)

// These IOCTLs apply to both the adapter and virtual adapter object
#define IOCTL_GET_STATISTICS				CTL_CODE(FILE_DEVICE_PROTOCOL, kIoctlFunction_GetStatistics,			METHOD_BUFFERED, FILE_ANY_ACCESS)


// NETSV_REGISTER_GUEST.fFlags constants
#define kVirtualSwitchRegisterGuestFlag_AddressActionMask	0x00000003
#define	kVirtualSwitchRegisterGuestFlag_GenerateAddress		0x00000000	// The VPCNetSv driver should generate a unique MAC address
#define	kVirtualSwitchRegisterGuestFlag_AddressIsSuggested	0x00000001	// The VPCNetSv driver should use the specified address if not already in use - generate a new one otherwise
#define kVirtualSwitchRegisterGuestFlag_AddressIsExclusive	0x00000002	// The VPCNetSv driver must use the specified address - fail if not available
#define kVirtualSwitchRegisterGuestFlag_AddressMayDuplicate	0x00000003	// The VPCNetSv driver must use the specified address - may duplicate an existing address

#define kVirtualSwitchRegisterGuestFlag_AddressWasGenerated	0x80000000	// The VPCNetSv driver generated a new MAC address

#define OID_GEN_CURRENT_PACKET_FILTER			0x0001010E	// Set or Query
#define OID_802_3_CURRENT_ADDRESS           	0x01010102	// Query only

#if 0
#define NDIS_PACKET_TYPE_DIRECTED				0x00000001
#define NDIS_PACKET_TYPE_MULTICAST				0x00000002
#define NDIS_PACKET_TYPE_ALL_MULTICAST			0x00000004
#define NDIS_PACKET_TYPE_BROADCAST				0x00000008
#define NDIS_PACKET_TYPE_PROMISCUOUS			0x00000020
#endif

#define DEFAULT_PACKET_FILTER	(NDIS_PACKET_TYPE_DIRECTED + NDIS_PACKET_TYPE_MULTICAST + NDIS_PACKET_TYPE_BROADCAST)


#pragma pack(push)
#pragma pack(1)

typedef struct
{
	ULONG			fAdapterID;
}NETSV_CREATE_VIRTUAL_ADAPTER, *PNETSV_CREATE_VIRTUAL_ADAPTER;

#define ETHERNET_ADDRESS_LENGTH 6

typedef struct
{
	UINT16			fVersion;								// Version of this structure
	UINT16			fLength;								// Length of following data
	ULONG			fFlags;									// Flags
	BYTE			fMACAddress[ETHERNET_ADDRESS_LENGTH];	// Guest VM MAC address
}NETSV_REGISTER_GUEST, *PNETSV_REGISTER_GUEST;

#define NETSV_REGISTER_GUEST_VERSION	0x0002
#define	NETSV_REGISTER_GUEST_LENGTH		(sizeof(NETSV_REGISTER_GUEST) - 2*sizeof(UINT16))

#define MAX_ADAPTERS						256
#define MAX_ADAPTER_BUFFER_SIZE				65536

#pragma pack(pop)


//=============================================================================
//    Function: VirtualpcDriverGetSymbolicName().
//
//    Description: Get the NT symbolic name for the packet driver we want.
//                 The driver supports multiple ones, we'll go for the first
//                 that has an ethernet address assigned and is not in use.
//=============================================================================

//static
BOOLEAN
VirtualpcDriverGetSymbolicName(
    OUT wchar_t * SymbolicName
    )
{
    void *        hControl;
    DWORD         BytesReturned;
	UINT32        version;
    wchar_t        Buffer[1024];
    wchar_t       *pAdapterInfo;
    BOOL          bResult;
	
	hControl = CreateFileW(NETSV_DRIVER_NAME, 
		                  GENERIC_READ | GENERIC_WRITE, 
                          FILE_SHARE_READ|FILE_SHARE_WRITE, NULL, 
						  OPEN_EXISTING, 
						  FILE_FLAG_OVERLAPPED|FILE_FLAG_NO_BUFFERING, 
						  NULL);
						  
	if (hControl == INVALID_HANDLE_VALUE)
	{
//		printf("Failed to open VirtualPC Network driver - not installed?\n");
		return FALSE;
	}

	if (DeviceIoControl(hControl, 
						(UINT32)IOCTL_GET_VERSION,
						NULL, 0,
						&version, sizeof(version),
						&BytesReturned,
						NULL) == FALSE)
	{
//		printf("Bad VirtualPC Network driver - no version?!?\n");
		CloseHandle(hControl);
		return FALSE;
	}
	if (version < kVPCNetSvVersion)
	{
//		printf("Warning:  VirtualPC Network driver has unexpected version (Actual: %x, Expected: %x)\n", version, kVPCNetSvVersion);
	}

    bResult = DeviceIoControl(
                        hControl,
                        IOCTL_ENUM_ADAPTERS,
                        NULL,
                        0,
                        Buffer,
                        sizeof(Buffer),
                        &BytesReturned,
                        NULL
                        );

    if ( bResult == FALSE )
    {
        return FALSE;
    }

    pAdapterInfo = (wchar_t *) Buffer;

    //
    // Skip the number of adapters, we'll just take the first one.
    //

    pAdapterInfo += 2; /* a one-wchar 'string' */

    //
    //    Skip the adapter name.
    //

    while( *pAdapterInfo != (wchar_t) '\0' )
    {
        pAdapterInfo++;
    }

    pAdapterInfo++;        //... Skip the NULL.

    //
    //    Copy the symbolic name.
    //

    while( *pAdapterInfo != (wchar_t) '\0' )
    {
        *SymbolicName++ = *pAdapterInfo++;
    }

    *SymbolicName++ = (wchar_t) '\0';

    CloseHandle(hControl)
;
    return TRUE;
}

//=============================================================================
//    Function: VirtualpcDriverOpenAdapter().
//
//    Description: Open the packet driver.
//=============================================================================
//static
HANDLE
VirtualpcDriverOpenAdapter(
    wchar_t * SymbolicName,
    OUT HANDLE  * phAuxHandle
    )
{
    wchar_t    AdapterName[1024];
    HANDLE    hHostAdapter = INVALID_HANDLE_VALUE;
    HANDLE    hVirtualAdapter = INVALID_HANDLE_VALUE;
    ULONG     bytesReturned;
    NETSV_CREATE_VIRTUAL_ADAPTER createAdapter;

    wsprintfW(
              AdapterName,
              L"\\\\.\\%s",
              &SymbolicName[12]
              );

    hHostAdapter = CreateFileW(
                               AdapterName,
                               GENERIC_WRITE | GENERIC_READ,
                               FILE_SHARE_READ | FILE_SHARE_WRITE,
                               NULL,
                               OPEN_EXISTING,
                               FILE_FLAG_OVERLAPPED,
                               0
                               );

    if (hHostAdapter == INVALID_HANDLE_VALUE)
    {
//        printf("Failed to open VirtualPC Host adapter - not installed?\n");
        goto Bad;
    }

    // Create an adapter instance, starting low
    createAdapter.fAdapterID = 0;
	
    if (DeviceIoControl(hHostAdapter,
						(UINT32)IOCTL_CREATE_VIRTUAL_ADAPTER,
						&createAdapter, sizeof(createAdapter),
						&createAdapter, sizeof(createAdapter),
						&bytesReturned,
						NULL) == FALSE)
    {
//        printf("Failed to create VirtualPC Host adapter instance\n");
        goto Bad;
    }

    hVirtualAdapter = VirtualpcDriverInitializeInstance(
                                 SymbolicName,
                                 AdapterName,
                                 createAdapter.fAdapterID);

    // Done
    //
    sprintf_s((char*)SymbolicName, 1024, "%ls", AdapterName);


 Bad:
    /* Apparently, hHostAdapter must remain opened. Yeach. */
    if (hVirtualAdapter == INVALID_HANDLE_VALUE)
    {
        CloseHandle(hHostAdapter);
        hHostAdapter = INVALID_HANDLE_VALUE;
    }
    *phAuxHandle = hHostAdapter;
    return hVirtualAdapter;
}


//=============================================================================
//  Function: PacketDriverSetFilter().
//
//  Description: Set capture filters.
//=============================================================================

HRESULT
VirtualpcDriverSetFilter(
    IN HANDLE hFile,
    IN ULONG  Filter
    )
{
    ULONG               IoCtlBufferLength = sizeof(PACKET_OID_DATA)-1 + sizeof(ULONG);
    BYTE                IoCtlBuffer[sizeof(PACKET_OID_DATA)-1 + sizeof(ULONG)];
    PPACKET_OID_DATA    OidData = NULL;
    BOOL                bResult;

    memset(IoCtlBuffer, 0, IoCtlBufferLength);
    OidData = (PPACKET_OID_DATA) IoCtlBuffer;
    OidData->Oid = OID_GEN_CURRENT_PACKET_FILTER;
    OidData->Length = sizeof(ULONG);

    memcpy(OidData->Data, &Filter, sizeof Filter);

    bResult = VirtualpcDriverRequest(hFile, TRUE, OidData);

    return (bResult ? S_OK : E_FAIL);
}

//=============================================================================
//  Function: PacketDriverRequest().
//
//  Description: Submit a request to the packet driver.
//=============================================================================

BOOL
VirtualpcDriverRequest(
    IN HANDLE hFile,
    IN BOOL Set,
    IN PPACKET_OID_DATA OidData
    )
{
    DWORD   BytesReturned;
    BOOL    bResult;
    UINT32   OidCommand;
    UINT32   OidLength;

    OidLength = sizeof(PACKET_OID_DATA) - 1 + OidData->Length;

    if ( Set != FALSE )
    {
        OidCommand = IOCTL_PROTOCOL_SET_OID;
    }
    else
    {
        OidCommand = IOCTL_PROTOCOL_QUERY_OID;
    }
    
    //
    //  Submit request.
    //

    bResult = DeviceIoControl(
                        hFile,
                        OidCommand,
                        OidData,
                        OidLength,
                        OidData,
                        OidLength,
                        &BytesReturned,
                        NULL
                        );

    return bResult;
}

static char MicKey[] = "SOFTWARE\\Microsoft\\Invisible Computing";
static char MicKeyMac[] = "SerplexMAC";

static
HRESULT
SetMyVirtualMac( IN BYTE *Mac)
{
	int i;

	MyMacP = (ULONG *) malloc(sizeof(ULONG) * 6);

	if(!MyMacP){
		printf("Failed to create MAC address\n");
		return E_FAIL;
	}

	for(i = 0; i < 6; i++){
		MyMacP[i] = (ULONG) Mac[i];
	}

	return S_OK;
}

static
HRESULT
GetMyVirtualMac( OUT BYTE *EthernetAddress)
{
	int i;
	if(!MyMacP){
		printf("MAC address not yet assigned\n");
		return E_FAIL;
	}
	
	for(i = 0; i < 6; i++){
		EthernetAddress[i] = (BYTE) MyMacP[i];
	}

	return S_OK;
}

static
HANDLE
VirtualpcDriverInitializeInstance(
    wchar_t * SymbolicName,
    wchar_t * AdapterName,
    UINT32 AdapterID
    )
{
    HANDLE hVirtualAdapter;

    wsprintfW(
              AdapterName,
              L"\\\\.\\%s_%08lX", 
              &SymbolicName[12],
              AdapterID);
    AdapterName[1024-1]=L'\0';
	
    hVirtualAdapter = CreateFileW(AdapterName, 
                                  GENERIC_READ | GENERIC_WRITE, 
                                  FILE_SHARE_READ|FILE_SHARE_WRITE,
                                  NULL, 
                                  OPEN_EXISTING, 
                                  FILE_FLAG_OVERLAPPED|FILE_FLAG_NO_BUFFERING, 
                                  NULL);


	// Register with the driver
    if (hVirtualAdapter != INVALID_HANDLE_VALUE)
	{
        DWORD  BytesReturned;
        HRESULT sc;
        NETSV_REGISTER_GUEST GuestInfo;

        memset(&GuestInfo,0,sizeof GuestInfo);
        GuestInfo.fVersion	 = NETSV_REGISTER_GUEST_VERSION;
        GuestInfo.fLength	 = NETSV_REGISTER_GUEST_LENGTH;

        /* Do we have a MAC to use
         */
        sc = GetMyVirtualMac(GuestInfo.fMACAddress);

        /* If not, generate a new one
         */
        if (FAILED(sc))
     	{
            GuestInfo.fFlags = kVirtualSwitchRegisterGuestFlag_GenerateAddress;
        }
        else
     	{
            GuestInfo.fFlags = kVirtualSwitchRegisterGuestFlag_AddressIsExclusive;
        }

        if (DeviceIoControl(hVirtualAdapter,
					    (UINT32)IOCTL_REGISTER_GUEST,
						&GuestInfo, sizeof(GuestInfo),
						&GuestInfo, sizeof(GuestInfo),
						&BytesReturned,
						NULL) == FALSE) 
        {
//            printf("VirtualSwitchRegisterAdaptor failed (error %d)\n", GetLastError());
            CloseHandle(hVirtualAdapter);
            hVirtualAdapter = INVALID_HANDLE_VALUE;
        }
	
        /* Remember if we got a new one
         */
        if (GuestInfo.fFlags & kVirtualSwitchRegisterGuestFlag_AddressWasGenerated) 
        {
#if 0
            int i;
            printf("VirtualPCDriver::A new Guest MAC address was generated");
            for (i = 0; i < ETHERNET_ADDRESS_LENGTH; i++)
                printf(":%x",GuestInfo.fMACAddress[i]);
            printf("\n");
#endif
            SetMyVirtualMac(GuestInfo.fMACAddress);
        }
    }
	
    return hVirtualAdapter;
}


//=============================================================================
//    Function: VirtualpcDriverGetAddress().
//
//    Description: Get the card's ethernet address.
//=============================================================================

//static
HRESULT 
VirtualpcDriverGetAddress(
    IN HANDLE hFile,
    IN BYTE *EthernetAddress
    )
{
    UnusedParameter(hFile);

    return GetMyVirtualMac(EthernetAddress);
}

//=============================================================================
//  Function: FlushPacketDriver()
//
//=============================================================================
// Flush all pending recieves.  We manage transmissions through acks, so
// they should be added to the free list before we call this function.
void
FlushPacketDriver(
    PPACKET_DRIVER_STATE PacketDriver
    )
{
    PACKET *Packet;
    DWORD           Transferred;
    BOOL            bResult;
    OVERLAPPED *    Overlapped;
#if (_MSC_VER > 1200)
    ULONG_PTR       Key;
#else
    UINT_PTR        Key;
#endif

	if(MyMacP){
		free(MyMacP);
	}

	//If the packet driver didn't get all the way through the openPacketDriver
	// function, there aren't any packets to finish completing or free up.
    if (!PacketDriver->bInitialized)
        return;

    CancelIo(PacketDriver->hFile);

    for (;;) 
    {
        //
        //  Wait for an I/O to complete.
        //
        
        Packet = NULL;
        Overlapped = NULL;

        bResult = GetQueuedCompletionStatus(
                            PacketDriver->IoCompletionPort,
                            &Transferred,
                            &Key,
                            &Overlapped,
                            0);

        //
        //  If the completion was ok, put packets into the FreePackets list. Else done.
        //

        if (Overlapped == NULL)
            break;

        Packet = (PACKET *) Overlapped;
		
        PacketFree(PacketDriver, Packet);
    }

    /* Now that all of the packets have been collected, free the allocated memory
     */
    while ((Packet = PacketDriver->FreePackets) != NULL)
    {
         PacketDriver->FreePackets = Packet->Next;
		 free(Packet->Buffer);
		 Packet->Length = 0;
         delete Packet;
    }
}
