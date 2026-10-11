/*********************************************************/
//	NKWINMAC.H
//		Header file for matching Win(VC++) and Mac(Code Warrier)
//
//
//		Copyright Nikon Corporation - All rights reserved
/*********************************************************/
//	1997. 8. 6		by mura.
/*********************************************************/
#ifndef _NKWINMAC_H
#define _NKWINMAC_H

///////////////////////////////////////////////////////////
//
#if defined( __APPLE__ )
	#include <time.h>
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	
#elif defined( USING_QT )
	#include <qfile.h>
	#include <qfileinfo.h>
	#include <qdatetime.h>
	#include <qstring.h>
	#include <stdio.h>
	#include <stdlib.h>
	#include <string.h>
	
#elif defined( _WIN32 )
	#include <windows.h>
	#include <windowsx.h>
	
#endif

///////////////////////////////////////////////////////////
//	It makes C4355 warning disable temporary. ( For VC++ )	
//
#if defined( _MSC_VER )
	#define NK_WARNING4355_DISABLE	warning(disable:4355)
	#define NK_WARNING4355_DEFAULT	warning(default:4355)
	
#else
	#define NK_WARNING4355_DISABLE
	#define NK_WARNING4355_DEFAULT
	
#endif

///////////////////////////////////////////////////////////
//	Replace Win32 Strings API to elsewhere ( C STD Library )
//
#if !defined( _WIN32 )
	#ifndef lstrcat
		#define	lstrcat		strcat
	#endif
	#ifndef lstrcmp
		#define	lstrcmp		strcmp
	#endif
	#ifndef lstrcpy
		#define	lstrcpy		strcpy
	#endif
	#ifndef lstrcpyn
		#define	lstrcpyn	strncpy
	#endif
	#ifndef lstrlen
		#define	lstrlen		strlen
	#endif
	#ifndef wsprintf
		#define wsprintf	sprintf
	#endif

	inline char* strcpy_s( char* strDest, size_t numberOfElements, const char* strSource )
	{
		return strcpy( strDest, strSource );
	}
	inline char* strncpy_s( char* strDest, size_t numberOfElements, const char* strSource, size_t count )
	{
		return strncpy(strDest, strSource, count);
	}
	inline int sprintf_s( char* buffer, size_t sizeOfBuffer, const char* format, ... )
	{
		int len = 0;
		va_list	argp;
		va_start( argp, format );
		len = vsprintf(buffer, format, argp);
		va_end( argp );
		return len;
	}
	inline int vsprintf_s( char* buffer, size_t numberOfElements, const char* format, va_list argptr )
	{
		return vsprintf(buffer, format, argptr);
	}

	inline char* strcat_s( char* strDest, size_t numberOfElements, const char* strSource )
	{
		return strcat(strDest, strSource);
	}
	inline char* strncat_s( char* strDest, size_t numberOfElements, const char* strSource, size_t count )
	{
		return strncat(strDest, strSource, count);
	}

	inline void _swab( char *src, char *dest, int n )
	{
		for( int i = 0; i < n; i++ ) dest[i] = src[n-1-i];
	}

	inline void ZeroMemory( void* p, unsigned long ulSize )
	{
		memset( p, 0, ulSize );
	}

	inline bool InvertByteOrder( char* pChar, unsigned long ulSize )
	{
		char cTmp;
		for ( unsigned long i = ulSize / 2 - 1; i >= 0; i-- ) {//changed_mac_64
			cTmp = pChar[ i ];
			pChar[ i ] = pChar[ ulSize - 1 - i ];
			pChar[ ulSize - 1 - i ] = cTmp;
		}
		return true;
	}
#endif

#if defined( __APPLE__ )
	inline char* _strdate( char *str )
	{
		time_t lTime;
		tm *pstTime;
		time( &lTime );
		pstTime = localtime( &lTime );
		sprintf( str, "%02d/%02d/%02d", pstTime->tm_mon, pstTime->tm_mday, pstTime->tm_year );
		return str;
	}
	inline char* _strtime( char *str )
	{
		time_t lTime;
		tm *pstTime;
		time( &lTime );
		pstTime = localtime( &lTime );
		sprintf( str, "%02d:%02d:%02d", pstTime->tm_hour, pstTime->tm_min, pstTime->tm_sec );
		return str;
	}

	inline void Sleep( unsigned int ulMillisSeconds )//changed_mac_64 TODO
	{
// for Legacy API start
		usleep( ulMillisSeconds * 1000 );
// for Legacy API end
	}
	
	inline short lstrcmpi( char *s1, char *s2 )
	{
		CFStringRef str1 = CFStringCreateWithCString( kCFAllocatorDefault, s1, CFStringGetSystemEncoding() );
		CFStringRef str2 = CFStringCreateWithCString( kCFAllocatorDefault, s2, CFStringGetSystemEncoding() );
		
		CFComparisonResult ret;
		ret = CFStringCompare( str1, str2, kCFCompareCaseInsensitive );
		CFRelease( str1 );
		CFRelease( str2 );
		
		return ret;
	}

#elif defined( USING_QT )
	inline char* _strdate( char *str )
	{
		QString sDate = QDate::currentDate().toString( "MM/DD/YY" );
		return strcpy( str, sDate );
	}
	inline char* _strtime( char *str )
	{
		QString sTime = QTime::currentTime().toString( "HH:MM:SS" );
		return strcpy( str, sTime );
	}

	inline void Sleep( unsigned long ulMilliSeconds )
	{
		(void)ulMilliSeconds;
		Q_ASSERT( FALSE );
	}
	
	inline short lstrcmpi( char *s1, char *s2 )
	{
		return QString( s1 ).upper().localeAwareCompare( QString( s2 ).upper() );
	}

#endif

///////////////////////////////////////////////////////////
//	typedef definition.(VC++)
//
#if defined(__APPLE__)
	typedef unsigned char		BYTE;
	typedef unsigned short		USHORT;
	typedef unsigned short		WORD;
//changed_mac_64 start
//	typedef long				HRESULT;
    typedef unsigned int		HRESULT;
//	typedef unsigned long		DWORD;
    typedef unsigned int		DWORD;
//changed_mac_64 end
	typedef const unsigned char*	LPCSTR;
	typedef const char*			LPCTSTR;
	typedef short				HINSTANCE;
	typedef char*				LPSTR;
	typedef						LPSTR LPTSTR;
	typedef unsigned int		UINT;
	typedef void*				HANDLE;

	typedef void*			PVOID;
//changed_mac_64 start
//	typedef long			LONG;
	typedef int				LONG;
//changed_mac_64 end
//	typedef unsigned long	ULONG;
	typedef short			SWORD;
//	typedef SWORD			BOOL;

	#define interface		class
	#define __int32			long
	#define __int16			short
	#define __int8			char
	
	#define LOWORD( l )		((WORD)(((long)(l)) & 0xffff))//changed_mac_64
	#define HIWORD( l )		((WORD)((((long)(l)) >> 16) & 0xffff))//changed_mac_64
	#define LOBYTE( w )		((BYTE)(((long)(w)) & 0xff))//changed_mac_64
	#define HIBYTE( w )		((BYTE)((((long)(w)) >> 8) & 0xff))//changed_mac_64
	
#endif

///////////////////////////////////////////////////////////
//	typedef definition.(Macintosh ToolBox)
//
#if defined(_WIN32)
	typedef __int8 SInt8;
	typedef __int16 SInt16;
	typedef __int32 SInt32;
//	typedef __int64 SInt64;
	typedef unsigned __int8 UInt8;
	typedef unsigned __int16 UInt16;
	typedef unsigned __int32 UInt32;
//	typedef unsigned __int64 UInt64;
#endif

///////////////////////////////////////////////////////////
//	Definition (WINNT.H)
#if !defined( _WIN32 )
	#define DLL_PROCESS_ATTACH 1    
	#define DLL_THREAD_ATTACH  2    
	#define DLL_THREAD_DETACH  3    
	#define DLL_PROCESS_DETACH 0    
#endif

///////////////////////////////////////////////////////////
//	Definition for COM (HRESULT value)
#if !defined( _WIN32 )
	#define _HRESULT_TYPEDEF_(_sc) ((HRESULT)_sc)

	#define NOERROR			0
	#define S_OK			((HRESULT)0x00000000L)
//	#define S_FALSE			((HRESULT)0x00000001L)

	#define E_UNEXPECTED	_HRESULT_TYPEDEF_(0x8000FFFFL)
//	#define E_NOTIMPL		_HRESULT_TYPEDEF_(0x80000001L)
	#define E_OUTOFMEMORY	_HRESULT_TYPEDEF_(0x80000002L)
	#define E_INVALIDARG	_HRESULT_TYPEDEF_(0x80000003L)
	#define E_NOINTERFACE	_HRESULT_TYPEDEF_(0x80000004L)
//	#define E_POINTER		_HRESULT_TYPEDEF_(0x80000005L)
//	#define E_HANDLE		_HRESULT_TYPEDEF_(0x80000006L)
//	#define E_ABORT			_HRESULT_TYPEDEF_(0x80000007L)
//	#define E_FAIL			_HRESULT_TYPEDEF_(0x80000008L)
//	#define E_ACCESSDENIED	_HRESULT_TYPEDEF_(0x80000009L)
//	#define E_PENDING		_HRESULT_TYPEDEF_(0x8000000AL)
	#define REGDB_E_CLASSNOTREG		_HRESULT_TYPEDEF_(0x80040154L)
#endif
	
///////////////////////////////////////////////////////////
//	Definition for memory allocation
#define Nkmalloc(x)	malloc(x)
#define Nkfree(x)	free(x)
#define Nknew		new

///////////////////////////////////////////////////////////
#if defined( USING_QT ) && defined( _MSC_VER )
	#include <algorithm>
	#define min	std::_cpp_min
	#define max	std::_cpp_max
#endif

///////////////////////////////////////////////////////////
#endif
