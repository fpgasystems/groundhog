// Title: Basic conversion functions
//
// Copyright: Microsoft 2009
//
// Author: Ken Eguro
//
// Created: 10/23/09 
//
// Version: 1.00
// 
// 
// Changelog: 
//
//----------------------------------------------------------------------------
#include "include.h"

BYTE *atoh(char* inStr, int length){
	BYTE *tempHex;

	size_t i;

	if(length != strlen(inStr) / 2){
		printf("String is not correct length!\n");
		return 0;
	}

	tempHex = (BYTE *) malloc(sizeof BYTE * strlen(inStr) / 2);
	
	memset(tempHex, 0, strlen(inStr) / 2);

	for(i = 0; i < strlen(inStr); i++){
		tempHex[i / 2] = tempHex[i / 2] << 4;
		if(inStr[i] >= '0' && inStr[i] <= '9'){
			tempHex[i / 2] += inStr[i] - '0';
		}
		else if(inStr[i] >= 'A' && inStr[i] <= 'F'){
			tempHex[i / 2] += inStr[i] - 'A' + 10;
		}
		else if(inStr[i] >= 'a' && inStr[i] <= 'f'){
			tempHex[i / 2] += inStr[i] - 'a' + 10;
		}
		else{
			printf("Unrecognized character : %c\n", inStr[i]);
			return 0;
		}
	}
	return tempHex;
}

bool atoh(char* inStr, int length, uint8_t *value){
	size_t i;

	if(length != strlen(inStr) / 2){
		printf("String is not correct length!\n");
		return 0;
	}

	if(!value){
		printf("Uninitialized pointer!\n");
		return false;
	}
	
	*value = 0;

	for(i = 0; i < strlen(inStr); i++){
		*value = *value << 4;
		if(inStr[i] >= '0' && inStr[i] <= '9'){
			*value += inStr[i] - '0';
		}
		else if(inStr[i] >= 'A' && inStr[i] <= 'F'){
			*value += inStr[i] - 'A' + 10;
		}
		else if(inStr[i] >= 'a' && inStr[i] <= 'f'){
			*value += inStr[i] - 'a' + 10;
		}
		else{
			printf("Unrecognized character : %c\n", inStr[i]);
			return false;
		}
	}
	return true;
}