#ifndef DNPSTATUSCODES_H
#define DNPSTATUSCODES_H

//============================================================================
// DNP Printer Status Codes
// Converted from VB.NET CyStat.vb for CyStat64.dll
//============================================================================

// Status Groups
#define GROUP_USUALLY       0x10000
#define GROUP_SETTING       0x20000
#define GROUP_HARDWARE      0x40000
#define GROUP_SYSTEM        0x80000
#define GROUP_FLSHPROG      0x100000

#define STATUS_ERROR        0x80000000

// Usually Status Group (Operational States)
#define STATUS_USUALLY_IDLE         (GROUP_USUALLY | 0x0001)
#define STATUS_USUALLY_PRINTING     (GROUP_USUALLY | 0x0002)
#define STATUS_USUALLY_STANDSTILL   (GROUP_USUALLY | 0x0004)
#define STATUS_USUALLY_PAPER_END    (GROUP_USUALLY | 0x0008)
#define STATUS_USUALLY_RIBBON_END   (GROUP_USUALLY | 0x0010)
#define STATUS_USUALLY_COOLING      (GROUP_USUALLY | 0x0020)
#define STATUS_USUALLY_MOTCOOLING   (GROUP_USUALLY | 0x0040)

// Setting Status Group (Configuration Issues)
#define STATUS_SETTING_COVER_OPEN   (GROUP_SETTING | 0x0001)
#define STATUS_SETTING_PAPER_JAM    (GROUP_SETTING | 0x0002)
#define STATUS_SETTING_RIBBON_ERR   (GROUP_SETTING | 0x0004)
#define STATUS_SETTING_PAPER_ERR    (GROUP_SETTING | 0x0008)
#define STATUS_SETTING_DATA_ERR     (GROUP_SETTING | 0x0010)
#define STATUS_SETTING_SCRAPBOX_ERR (GROUP_SETTING | 0x0020)

// Hardware Status Group (Hardware Errors)
#define STATUS_HARDWARE_ERR01       (GROUP_HARDWARE | 0x0001) // Head Voltage Error
#define STATUS_HARDWARE_ERR02       (GROUP_HARDWARE | 0x0002) // Head Position Error
#define STATUS_HARDWARE_ERR03       (GROUP_HARDWARE | 0x0004) // Fan Stop Error
#define STATUS_HARDWARE_ERR04       (GROUP_HARDWARE | 0x0008) // Cutter Error
#define STATUS_HARDWARE_ERR05       (GROUP_HARDWARE | 0x0010) // Pinch Roller Error
#define STATUS_HARDWARE_ERR06       (GROUP_HARDWARE | 0x0020) // Illegal Head Temperature
#define STATUS_HARDWARE_ERR07       (GROUP_HARDWARE | 0x0040) // Illegal Media Temperature
#define STATUS_HARDWARE_ERR08       (GROUP_HARDWARE | 0x0080) // Ribbon Tension Error
#define STATUS_HARDWARE_ERR09       (GROUP_HARDWARE | 0x0100) // RFID Module Error
#define STATUS_HARDWARE_ERR10       (GROUP_HARDWARE | 0x0200) // Illegal Motor Temperature

// System Status Group
#define STATUS_SYSTEM_ERR01         (GROUP_SYSTEM | 0x0001)

// Flash Programming Status Group
#define STATUS_FLSHPROG_IDLE        (GROUP_FLSHPROG | 0x0001)
#define STATUS_FLSHPROG_WRITING     (GROUP_FLSHPROG | 0x0002)
#define STATUS_FLSHPROG_FINISHED    (GROUP_FLSHPROG | 0x0004)
#define STATUS_FLSHPROG_DATA_ERR1   (GROUP_FLSHPROG | 0x0008)
#define STATUS_FLSHPROG_DEVICE_ERR1 (GROUP_FLSHPROG | 0x0010)
#define STATUS_FLSHPROG_OTHERS_ERR1 (GROUP_FLSHPROG | 0x0020)

// Cutter Modes
#define CUTTER_MODE_STANDARD        0x00
#define CUTTER_MODE_NONSCRAP        0x01
#define CUTTER_MODE_2INCHCUT        0x78

#endif // DNPSTATUSCODES_H
