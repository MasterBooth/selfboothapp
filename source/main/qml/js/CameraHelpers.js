// Helper functions for camera property display values

function findIndexInList(list, value) {
    for (var i = 0; i < list.length; i++) {
        if (list[i].value === value) return i
    }
    return -1
}

function getISODisplayValue(value) {
    if (!value) return "Auto"
    var isoMap = {
        0x00000028: "Auto", 0x00000040: "50", 0x00000048: "100", 0x0000004b: "125",
        0x0000004d: "160", 0x00000050: "200", 0x00000053: "250", 0x00000055: "320",
        0x00000058: "400", 0x0000005b: "500", 0x0000005d: "640", 0x00000060: "800",
        0x00000063: "1000", 0x00000065: "1250", 0x00000068: "1600", 0x0000006b: "2000",
        0x0000006d: "2500", 0x00000070: "3200", 0x00000073: "4000", 0x00000075: "5000",
        0x00000078: "6400", 0x0000007b: "8000", 0x0000007d: "10000", 0x00000080: "12800",
        0x00000083: "16000", 0x00000085: "20000", 0x00000088: "25600"
    }
    return isoMap[value] || value.toString()
}

function getApertureDisplayValue(value) {
    if (!value) return "f/--"
    var apertureMap = {
        0x0d: "f/1.2", 0x10: "f/1.4", 0x13: "f/1.8", 0x14: "f/2.0", 0x15: "f/2.2",
        0x18: "f/2.8", 0x1b: "f/3.5", 0x1c: "f/4.0", 0x1d: "f/4.5", 0x20: "f/5.6",
        0x23: "f/7.1", 0x24: "f/8.0", 0x25: "f/9.0", 0x28: "f/11", 0x2b: "f/14",
        0x2c: "f/16", 0x2d: "f/18", 0x30: "f/22", 0x33: "f/28", 0x34: "f/32"
    }
    return apertureMap[value] || "f/" + (value / 10.0).toFixed(1)
}

function getShutterSpeedDisplayValue(value) {
    if (!value) return "--"
    var shutterMap = {
        0x0c: "Bulb", 0x10: "30\"", 0x13: "25\"", 0x14: "20\"", 0x15: "20\"",
        0x18: "15\"", 0x1b: "13\"", 0x1c: "10\"", 0x1d: "10\"", 0x20: "8\"",
        0x23: "6\"", 0x24: "6\"", 0x25: "5\"", 0x28: "4\"", 0x2b: "3\"2",
        0x2c: "3\"", 0x2d: "2\"5", 0x30: "2\"", 0x33: "1\"6", 0x34: "1\"5",
        0x35: "1\"3", 0x38: "1\"", 0x3b: "0\"8", 0x3c: "0\"7", 0x3d: "0\"6",
        0x40: "0\"5", 0x43: "0\"4", 0x44: "0\"3", 0x45: "0\"3", 0x48: "1/4",
        0x4b: "1/5", 0x4c: "1/6", 0x4d: "1/6", 0x50: "1/8", 0x53: "1/10",
        0x54: "1/10", 0x55: "1/13", 0x58: "1/15", 0x5b: "1/20", 0x5c: "1/20",
        0x5d: "1/25", 0x60: "1/30", 0x63: "1/40", 0x64: "1/45", 0x65: "1/50",
        0x68: "1/60", 0x6b: "1/80", 0x6c: "1/90", 0x6d: "1/100", 0x70: "1/125",
        0x73: "1/160", 0x74: "1/180", 0x75: "1/200", 0x78: "1/250", 0x7b: "1/320",
        0x7c: "1/350", 0x7d: "1/400", 0x80: "1/500", 0x83: "1/640", 0x84: "1/750",
        0x85: "1/800", 0x88: "1/1000", 0x8b: "1/1250", 0x8c: "1/1500", 0x8d: "1/6400",
        0x90: "1/2000", 0x93: "1/2500", 0x94: "1/3000", 0x95: "1/3200", 0x98: "1/4000",
        0x9b: "1/5000", 0x9c: "1/6000", 0x9d: "1/6400", 0xa0: "1/8000"
    }
    return shutterMap[value] || "1/" + value
}

function getWhiteBalanceDisplayValue(value) {
    var wbMap = {
        0: "Auto", 1: "Daylight", 2: "Cloudy", 3: "Tungsten",
        4: "Fluorescent", 5: "Flash", 6: "Manual", 8: "Shade", 9: "Color Temp"
    }
    return wbMap[value] || "Custom"
}

function getImageQualityDisplayValue(value) {
    var qualityMap = {
        0x0210f0f: "L Fine", 0x0110f0f: "L Normal", 0x021f0f0: "M Fine",
        0x011f0f0: "M Normal", 0x0220f0f: "S1 Fine", 0x0120f0f: "S1 Normal",
        0x0230f0f: "S2 Fine", 0x0130f0f: "S2 Normal", 0x0240f0f: "S3 Fine",
        0x0140f0f: "S3 Normal", 0x0410f0f: "RAW", 0x0610f0f: "RAW + L Fine",
        0x0620f0f: "RAW + L Normal"
    }
    return qualityMap[value] || "Unknown"
}
