/*
Module Name:

    packet.h

Abstract:

Author:

Revision History:

    Converted to Windows 2000 - Eliyas Yakub 
	Cleared out outdated code - Ken Eguro, 10/23/09
--*/
#if 0
#include <ntddndis.h>
#else
//
// This is the type of an NDIS OID value.
//

typedef ULONG NDIS_OID, *PNDIS_OID;


//
// General Objects
//

#define OID_GEN_SUPPORTED_LIST              	0x00010101
#define OID_GEN_HARDWARE_STATUS             	0x00010102
#define OID_GEN_MEDIA_SUPPORTED             	0x00010103
#define OID_GEN_MEDIA_IN_USE                	0x00010104
#define OID_GEN_MAXIMUM_LOOKAHEAD           	0x00010105
#define OID_GEN_MAXIMUM_FRAME_SIZE          	0x00010106
#define OID_GEN_LINK_SPEED                  	0x00010107
#define OID_GEN_TRANSMIT_BUFFER_SPACE       	0x00010108
#define OID_GEN_RECEIVE_BUFFER_SPACE        	0x00010109
#define OID_GEN_TRANSMIT_BLOCK_SIZE         	0x0001010A
#define OID_GEN_RECEIVE_BLOCK_SIZE          	0x0001010B
#define OID_GEN_VENDOR_ID                   	0x0001010C
#define OID_GEN_VENDOR_DESCRIPTION          	0x0001010D
#define OID_GEN_CURRENT_PACKET_FILTER       	0x0001010E
#define OID_GEN_CURRENT_LOOKAHEAD           	0x0001010F
#define OID_GEN_DRIVER_VERSION              	0x00010110
#define OID_GEN_MAXIMUM_TOTAL_SIZE          	0x00010111
#define OID_GEN_PROTOCOL_OPTIONS            	0x00010112
#define OID_GEN_MAC_OPTIONS                 	0x00010113
#define OID_GEN_MEDIA_CONNECT_STATUS        	0x00010114
#define OID_GEN_MAXIMUM_SEND_PACKETS        	0x00010115
#define OID_GEN_VENDOR_DRIVER_VERSION           0x00010116

#define OID_GEN_XMIT_OK                     	0x00020101
#define OID_GEN_RCV_OK                      	0x00020102
#define OID_GEN_XMIT_ERROR                  	0x00020103
#define OID_GEN_RCV_ERROR                   	0x00020104
#define OID_GEN_RCV_NO_BUFFER               	0x00020105

#define OID_GEN_DIRECTED_BYTES_XMIT         	0x00020201
#define OID_GEN_DIRECTED_FRAMES_XMIT        	0x00020202
#define OID_GEN_MULTICAST_BYTES_XMIT        	0x00020203
#define OID_GEN_MULTICAST_FRAMES_XMIT       	0x00020204
#define OID_GEN_BROADCAST_BYTES_XMIT        	0x00020205
#define OID_GEN_BROADCAST_FRAMES_XMIT       	0x00020206
#define OID_GEN_DIRECTED_BYTES_RCV          	0x00020207
#define OID_GEN_DIRECTED_FRAMES_RCV         	0x00020208
#define OID_GEN_MULTICAST_BYTES_RCV         	0x00020209
#define OID_GEN_MULTICAST_FRAMES_RCV        	0x0002020A
#define OID_GEN_BROADCAST_BYTES_RCV         	0x0002020B
#define OID_GEN_BROADCAST_FRAMES_RCV        	0x0002020C

#define OID_GEN_RCV_CRC_ERROR               	0x0002020D
#define OID_GEN_TRANSMIT_QUEUE_LENGTH       	0x0002020E

//
// These are objects for Connection-oriented media call-managers and are not
// valid for ndis drivers. Under construction.
//
#define OID_CO_ADD_PVC							0xFF000001
#define OID_CO_DELETE_PVC						0xFF000002
#define OID_CO_GET_CALL_INFORMATION				0xFF000003
#define OID_CO_ADD_ADDRESS						0xFF000004
#define OID_CO_DELETE_ADDRESS					0xFF000005
#define OID_CO_GET_ADDRESSES					0xFF000006
#define OID_CO_ADDRESS_CHANGE					0xFF000007
#define OID_CO_SIGNALING_ENABLED				0xFF000008
#define OID_CO_SIGNALING_DISABLED				0xFF000009
#define OID_CO_REGISTER_FOR_CONNECTIONLESS		0xFF00000A	// supported by SPANS signaling only
#define OID_CO_DEREGISTER_FOR_CONNECTIONLESS	0xFF00000B	// supported by SPANS signaling only
#define OID_CO_SEND_CONNECTIONLESS				0xFF00000C	// supported by SPANS signaling only
#define OID_CO_INDICATE_CONNECTIONLESS			0xFF00000D	// supported by SPANS signaling only


//
// 802.3 Objects (Ethernet)
//

#define OID_802_3_PERMANENT_ADDRESS         	0x01010101
#define OID_802_3_CURRENT_ADDRESS           	0x01010102
#define OID_802_3_MULTICAST_LIST            	0x01010103
#define OID_802_3_MAXIMUM_LIST_SIZE         	0x01010104
#define OID_802_3_MAC_OPTIONS		         	0x01010105

//
// Bits for OID_802_3_MAC_OPTIONS
//
#define	NDIS_802_3_MAC_OPTION_PRIORITY			0x00000001

#define OID_802_3_RCV_ERROR_ALIGNMENT       	0x01020101
#define OID_802_3_XMIT_ONE_COLLISION        	0x01020102
#define OID_802_3_XMIT_MORE_COLLISIONS      	0x01020103

#define OID_802_3_XMIT_DEFERRED             	0x01020201
#define OID_802_3_XMIT_MAX_COLLISIONS       	0x01020202
#define OID_802_3_RCV_OVERRUN               	0x01020203
#define OID_802_3_XMIT_UNDERRUN             	0x01020204
#define OID_802_3_XMIT_HEARTBEAT_FAILURE    	0x01020205
#define OID_802_3_XMIT_TIMES_CRS_LOST       	0x01020206
#define OID_802_3_XMIT_LATE_COLLISIONS      	0x01020207


//
// Ndis Packet Filter Bits (OID_GEN_CURRENT_PACKET_FILTER).
//

#define NDIS_PACKET_TYPE_DIRECTED           0x0001
#define NDIS_PACKET_TYPE_MULTICAST          0x0002
#define NDIS_PACKET_TYPE_ALL_MULTICAST      0x0004
#define NDIS_PACKET_TYPE_BROADCAST          0x0008
#define NDIS_PACKET_TYPE_SOURCE_ROUTING     0x0010
#define NDIS_PACKET_TYPE_PROMISCUOUS        0x0020
#define NDIS_PACKET_TYPE_SMT                0x0040
#define NDIS_PACKET_TYPE_ALL_LOCAL          0x0080
#define NDIS_PACKET_TYPE_MAC_FRAME          0x8000
#define NDIS_PACKET_TYPE_FUNCTIONAL         0x4000
#define NDIS_PACKET_TYPE_ALL_FUNCTIONAL     0x2000
#define NDIS_PACKET_TYPE_GROUP              0x1000


#endif

#define NT_DEVICE_NAME L"\\Device\\Packet"
#define DOS_DEVICE_NAME L"\\DosDevices\\Packet"

//#define  ETHERNET_HEADER_LENGTH   14

//#define  TRANSMIT_PACKETS    128

#define        MAX_LINK_NAME_LENGTH   1024

typedef struct _PACKET_OID_DATA {

    ULONG           Oid;
    ULONG           Length;
    UCHAR           Data[1];

}   PACKET_OID_DATA, *PPACKET_OID_DATA;


#define FILE_DEVICE_PROTOCOL        0x8000



#define IOCTL_PROTOCOL_SET_OID      (DWORD)CTL_CODE(FILE_DEVICE_PROTOCOL, 0 , METHOD_BUFFERED, FILE_ANY_ACCESS)
#define IOCTL_PROTOCOL_QUERY_OID    (DWORD)CTL_CODE(FILE_DEVICE_PROTOCOL, 1 , METHOD_BUFFERED, FILE_ANY_ACCESS)

#define IOCTL_PROTOCOL_RESET        (DWORD)CTL_CODE(FILE_DEVICE_PROTOCOL, 2 , METHOD_BUFFERED, FILE_ANY_ACCESS)
#define IOCTL_ENUM_ADAPTERS         (DWORD)CTL_CODE(FILE_DEVICE_PROTOCOL, 3 , METHOD_BUFFERED, FILE_ANY_ACCESS)

//
// State required by the packet driver routines
//
typedef enum _PACKET_MODE {
    PacketModeInvalid = 0,
    PacketModeReceiving = 1,
    PacketModeTransmitting = 2,
    PacketModeTransmittingBuffer = 3
} PACKET_MODE;

/* Packet descriptor. */
typedef struct _PACKET PACKET, *PPACKET;

struct _PACKET {
    OVERLAPPED  Overlapped;                     
    PACKET      *Next;
    PACKET_MODE Mode;
    HRESULT     Result;
    UINT32      Length;			//Maximum length of packet (size of buffer)
    UINT32      nBytesAvail;	//Length of actual data in packet
    uint8_t     *Buffer;

	//If this is a command packet, we don't know if the command itself or
	//  it's ack will complete first.  Thus, we need to keep track of
	//  both here and only free the packet when both have completed.
	BOOL		completed;
	BOOL		acked;
};


/* Network interface  */
typedef struct _PACKET_DRIVER_STATE PACKET_DRIVER_STATE, * PPACKET_DRIVER_STATE;

struct _PACKET_DRIVER_STATE{
    /* NT handles */
    HANDLE hFile;
    HANDLE IoCompletionPort;
    HANDLE AuxHandle;

    /* Count of posted I/Os */
    //UINT nRecvPosted;
    //UINT nIoPosted;

    /* Pool of frequently used dynamic data */
    PACKET *FreePackets;

    /* The network address. */
    BYTE EthernetAddress[6];

    BOOL bInitialized;

    /* If you need more stuff... */
#ifdef ADDITIONAL_PACKET_DRIVER_STATE
    ADDITIONAL_PACKET_DRIVER_STATE
#endif
} ;

void
PacketInit( 
    PACKET * Packet
    );

void
PacketAllocate( 
    PPACKET_DRIVER_STATE PacketDriver,
    PACKET ** Packet
	);

void
PacketFree( 
    PPACKET_DRIVER_STATE PacketDriver,
    PACKET * Packet
    );

HRESULT
PacketWriteFile(    
    IN HANDLE hFile,
    IN PACKET * Packet
    );

HRESULT
PacketReadFile( 
    HANDLE hFile,
    PACKET * Packet
    );

void UnusedParameter(void *temp);

BOOLEAN VirtualpcDriverGetSymbolicName(OUT wchar_t * SymbolicName);
HANDLE VirtualpcDriverOpenAdapter(wchar_t * SymbolicName,OUT HANDLE  * phAuxHandle);
BOOL VirtualpcDriverRequest(IN HANDLE hFile, IN BOOL Set, IN PPACKET_OID_DATA OidData);

HRESULT VirtualpcDriverSetFilter(IN HANDLE hFile, IN ULONG  Filter);
static HANDLE VirtualpcDriverInitializeInstance(wchar_t * SymbolicName, wchar_t * AdapterName, UINT32 AdapterID);
HRESULT VirtualpcDriverGetAddress(IN HANDLE hFile, IN BYTE *EthernetAddress);

void FlushPacketDriver(PPACKET_DRIVER_STATE PacketDriver);
