#include "PropertyHelper.h"

PropertyHelper::PropertyHelper(QObject* parent) : QObject(parent) {}

QString PropertyHelper::isoToString(int value) const {
    switch (value) {
        case 0x00: return "Auto";
        case 0x28: return "6";
        case 0x30: return "12";
        case 0x38: return "25";
        case 0x40: return "50";
        case 0x48: return "100";
        case 0x4b: return "125";
        case 0x4d: return "160";
        case 0x50: return "200";
        case 0x53: return "250";
        case 0x55: return "320";
        case 0x58: return "400";
        case 0x5b: return "500";
        case 0x5d: return "640";
        case 0x60: return "800";
        case 0x63: return "1000";
        case 0x65: return "1250";
        case 0x68: return "1600";
        case 0x6b: return "2000";
        case 0x6d: return "2500";
        case 0x70: return "3200";
        case 0x73: return "4000";
        case 0x75: return "5000";
        case 0x78: return "6400";
        case 0x7b: return "8000";
        case 0x7d: return "10000";
        case 0x80: return "12800";
        case 0x83: return "16000";
        case 0x85: return "20000";
        case 0x88: return "25600";
        case 0x8b: return "32000";
        case 0x8d: return "40000";
        case 0x90: return "51200";
        case 0x93: return "64000";
        case 0x95: return "80000";
        case 0x98: return "102400";
        case 0xa0: return "204800";
        case 0xa8: return "409600";
        case -1: return "Invalid";
        default: return QString("ISO %1").arg(value, 0, 16);
    }
}

QString PropertyHelper::apertureToString(int value) const {
    switch (value) {
        case 0x08: return "f/1.0";
        case 0x0B: return "f/1.1";
        case 0x0C: return "f/1.2";
        case 0x0D: return "f/1.2";
        case 0x10: return "f/1.4";
        case 0x13: return "f/1.6";
        case 0x14: return "f/1.8";
        case 0x15: return "f/1.8";
        case 0x18: return "f/2.0";
        case 0x1B: return "f/2.2";
        case 0x1C: return "f/2.5";
        case 0x1D: return "f/2.5";
        case 0x20: return "f/2.8";
        case 0x23: return "f/3.2";
        case 0x24: return "f/3.5";
        case 0x25: return "f/3.5";
        case 0x28: return "f/4.0";
        case 0x2B: return "f/4.5";
        case 0x2C: return "f/4.5";
        case 0x2D: return "f/5.0";
        case 0x30: return "f/5.6";
        case 0x33: return "f/6.3";
        case 0x34: return "f/6.7";
        case 0x35: return "f/7.1";
        case 0x38: return "f/8.0";
        case 0x3B: return "f/9.0";
        case 0x3C: return "f/9.5";
        case 0x3D: return "f/10";
        case 0x40: return "f/11";
        case 0x43: return "f/13";
        case 0x44: return "f/13";
        case 0x45: return "f/14";
        case 0x48: return "f/16";
        case 0x4B: return "f/18";
        case 0x4C: return "f/19";
        case 0x4D: return "f/20";
        case 0x50: return "f/22";
        case 0x53: return "f/25";
        case 0x54: return "f/27";
        case 0x55: return "f/29";
        case 0x58: return "f/32";
        case 0x5B: return "f/36";
        case 0x5C: return "f/38";
        case 0x5D: return "f/40";
        case 0x60: return "f/45";
        case 0x63: return "f/51";
        case 0x64: return "f/54";
        case 0x65: return "f/57";
        case 0x68: return "f/64";
        case 0x6B: return "f/72";
        case 0x6C: return "f/76";
        case 0x6D: return "f/80";
        case 0x70: return "f/91";
        case -1: return "Invalid";
        default: return QString("Av 0x%1").arg(value, 2, 16, QChar('0'));
    }
}

QString PropertyHelper::shutterSpeedToString(int value) const {
    switch (value) {
        case 0x0C: return "Bulb";
        case 0x10: return "30\"";
        case 0x13: return "25\"";
        case 0x14: return "20\"";
        case 0x15: return "20\"";
        case 0x18: return "15\"";
        case 0x1B: return "13\"";
        case 0x1C: return "10\"";
        case 0x1D: return "10\"";
        case 0x20: return "8\"";
        case 0x23: return "6\"";
        case 0x24: return "6\"";
        case 0x25: return "5\"";
        case 0x28: return "4\"";
        case 0x2B: return "3\"2";
        case 0x2C: return "3\"";
        case 0x2D: return "2\"5";
        case 0x30: return "2\"";
        case 0x33: return "1\"6";
        case 0x34: return "1\"5";
        case 0x35: return "1\"3";
        case 0x38: return "1\"";
        case 0x3B: return "0\"8";
        case 0x3C: return "0\"7";
        case 0x3D: return "0\"6";
        case 0x40: return "0\"5";
        case 0x43: return "0\"4";
        case 0x44: return "0\"3";
        case 0x45: return "0\"3";
        case 0x48: return "1/4";
        case 0x4B: return "1/5";
        case 0x4C: return "1/6";
        case 0x4D: return "1/6";
        case 0x50: return "1/8";
        case 0x53: return "1/10";
        case 0x54: return "1/10";
        case 0x55: return "1/13";
        case 0x58: return "1/15";
        case 0x5B: return "1/20";
        case 0x5C: return "1/20";
        case 0x5D: return "1/25";
        case 0x60: return "1/30";
        case 0x63: return "1/40";
        case 0x64: return "1/45";
        case 0x65: return "1/50";
        case 0x68: return "1/60";
        case 0x6B: return "1/80";
        case 0x6C: return "1/90";
        case 0x6D: return "1/100";
        case 0x70: return "1/125";
        case 0x73: return "1/160";
        case 0x74: return "1/180";
        case 0x75: return "1/200";
        case 0x78: return "1/250";
        case 0x7B: return "1/320";
        case 0x7C: return "1/350";
        case 0x7D: return "1/400";
        case 0x80: return "1/500";
        case 0x83: return "1/640";
        case 0x84: return "1/750";
        case 0x85: return "1/800";
        case 0x88: return "1/1000";
        case 0x8B: return "1/1250";
        case 0x8C: return "1/1500";
        case 0x8D: return "1/1600";
        case 0x90: return "1/2000";
        case 0x93: return "1/2500";
        case 0x94: return "1/3000";
        case 0x95: return "1/3200";
        case 0x98: return "1/4000";
        case 0x9B: return "1/5000";
        case 0x9C: return "1/6000";
        case 0x9D: return "1/6400";
        case 0xA0: return "1/8000";
        case 0xA3: return "1/10000";
        case 0xA5: return "1/12800";
        case 0xA8: return "1/16000";
        case -1: return "Invalid";
        default: return QString("Tv 0x%1").arg(value, 2, 16, QChar('0'));
    }
}

QString PropertyHelper::exposureCompToString(int value) const {
    switch (value) {
        case 0x28: return "+5";
        case 0x25: return "+4 2/3";
        case 0x24: return "+4 1/2";
        case 0x23: return "+4 1/3";
        case 0x20: return "+4";
        case 0x1D: return "+3 2/3";
        case 0x1C: return "+3 1/2";
        case 0x1B: return "+3 1/3";
        case 0x18: return "+3";
        case 0x15: return "+2 2/3";
        case 0x14: return "+2 1/2";
        case 0x13: return "+2 1/3";
        case 0x10: return "+2";
        case 0x0D: return "+1 2/3";
        case 0x0C: return "+1 1/2";
        case 0x0B: return "+1 1/3";
        case 0x08: return "+1";
        case 0x05: return "+2/3";
        case 0x04: return "+1/2";
        case 0x03: return "+1/3";
        case 0x00: return "0";
        case 0xFD: return "-1/3";
        case 0xFC: return "-1/2";
        case 0xFB: return "-2/3";
        case 0xF8: return "-1";
        case 0xF5: return "-1 1/3";
        case 0xF4: return "-1 1/2";
        case 0xF3: return "-1 2/3";
        case 0xF0: return "-2";
        case 0xED: return "-2 1/3";
        case 0xEC: return "-2 1/2";
        case 0xEB: return "-2 2/3";
        case 0xE8: return "-3";
        case 0xE5: return "-3 1/3";
        case 0xE4: return "-3 1/2";
        case 0xE3: return "-3 2/3";
        case 0xE0: return "-4";
        case 0xDD: return "-4 1/3";
        case 0xDC: return "-4 1/2";
        case 0xDB: return "-4 2/3";
        case 0xD8: return "-5";
        default: return QString("%1").arg(value);
    }
}

QString PropertyHelper::whiteBalanceToString(int value) const {
    switch (value) {
        case 0: return "Auto";
        case 1: return "Daylight";
        case 2: return "Cloudy";
        case 3: return "Tungsten";
        case 4: return "Fluorescent";
        case 5: return "Flash";
        case 6: return "Manual";
        case 8: return "Shade";
        case 9: return "Color Temp";
        case 10: return "Custom 1";
        case 11: return "Custom 2";
        case 12: return "Custom 3";
        case 15: return "Manual 2";
        case 16: return "Manual 3";
        case 18: return "Manual 4";
        case 19: return "Manual 5";
        case 20: return "Custom 4";
        case 21: return "Custom 5";
        case 23: return "Auto (white priority)";
        default: return QString("WB %1").arg(value);
    }
}

QString PropertyHelper::driveModeToString(int value) const {
    switch (value) {
        case 0x00: return "Single";
        case 0x01: return "Continuous";
        case 0x02: return "Video";
        case 0x04: return "Continuous High";
        case 0x05: return "Continuous Low";
        case 0x06: return "Silent Single";
        case 0x07: return "Self-Timer 10s";
        case 0x10: return "Self-Timer 2s";
        case 0x11: return "Super High Speed Continuous";
        case 0x12: return "Silent Continuous";
        case 0x13: return "Silent HS Continuous";
        case 0x14: return "Silent LS Continuous";
        default: return QString("Drive %1").arg(value);
    }
}

QString PropertyHelper::aeModeToString(int value) const {
    switch (value) {
        case 0: return "P";
        case 1: return "Tv";
        case 2: return "Av";
        case 3: return "M";
        case 4: return "Bulb";
        case 5: return "A-DEP";
        case 6: return "DEP";
        case 7: return "Custom 1";
        case 8: return "Lock";
        case 9: return "Green";
        case 10: return "Night Portrait";
        case 11: return "Sports";
        case 12: return "Portrait";
        case 13: return "Landscape";
        case 14: return "Close-up";
        case 15: return "Flash Off";
        case 19: return "Creative Auto";
        case 20: return "Movie";
        case 21: return "Photo in Movie";
        case 22: return "Scene Intelligent Auto";
        case 23: return "SCN";
        case 24: return "Night Scenes";
        case 25: return "Backlit Scenes";
        case 26: return "Custom 2";
        case 27: return "Custom 3";
        case 28: return "Panning";
        case 29: return "Food";
        case 30: return "Group Photo";
        case 35: return "Flexible Priority";
        default: return QString("AE %1").arg(value);
    }
}

QString PropertyHelper::afModeToString(int value) const {
    switch (value) {
        case 0: return "One-Shot AF";
        case 1: return "AI Servo AF";
        case 2: return "AI Focus AF";
        case 3: return "Manual Focus";
        default: return QString("AF %1").arg(value);
    }
}

QString PropertyHelper::batteryLevelToString(int value) const {
    if (value == 0xffffffff) return "AC Power";
    if (value <= 100) return QString("%1%").arg(value);
    switch (value) {
        case 0: return "Empty";
        case 1: return "Low";
        case 2: return "Half";
        case 3: return "Full";
        default: return QString("%1").arg(value);
    }
}

QString PropertyHelper::imageQualityToString(int value) const {
    // This is a complex bitfield, simplified version
    int size = (value >> 24) & 0xFF;
    int type = value & 0xFF;

    QString sizeStr;
    switch (size) {
        case 0: sizeStr = "L"; break;
        case 1: sizeStr = "M"; break;
        case 2: sizeStr = "S"; break;
        case 5: sizeStr = "M1"; break;
        case 6: sizeStr = "M2"; break;
        case 14: sizeStr = "S1"; break;
        case 15: sizeStr = "S2"; break;
        case 16: sizeStr = "S3"; break;
        default: sizeStr = QString::number(size); break;
    }

    QString typeStr;
    switch (type) {
        case 1: typeStr = "JPEG"; break;
        case 2: typeStr = "JPEG (Normal)"; break;
        case 3: typeStr = "JPEG (Fine)"; break;
        case 4: typeStr = "RAW"; break;
        case 5: typeStr = "RAW+JPEG"; break;
        default: typeStr = QString("Type %1").arg(type); break;
    }

    return QString("%1 %2").arg(sizeStr, typeStr);
}
