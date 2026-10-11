/*
 * QR Code generator library (C++)
 *
 * Copyright (c) Project Nayuki. (MIT License)
 * https://www.nayuki.io/page/qr-code-generator-library
 */

#include "qrcodegen.hpp"

#include <algorithm>
#include <cassert>
#include <climits>
#include <cstddef>
#include <cstring>
#include <sstream>
#include <stdexcept>
#include <utility>

using std::int8_t;
using std::uint8_t;
using std::size_t;
using std::vector;


namespace qrcodegen {

/*---- Class QrSegment::Mode ----*/

const QrSegment::Mode QrSegment::Mode::NUMERIC     (0x1, 10, 12, 14);
const QrSegment::Mode QrSegment::Mode::ALPHANUMERIC(0x2,  9, 11, 13);
const QrSegment::Mode QrSegment::Mode::BYTE        (0x4,  8, 16, 16);
const QrSegment::Mode QrSegment::Mode::KANJI       (0x8,  8, 10, 12);
const QrSegment::Mode QrSegment::Mode::ECI         (0x7,  0,  0,  0);

QrSegment::Mode::Mode(int modeBits, int cc0, int cc1, int cc2) :
    modeBits_(modeBits) {
    numBitsCharCount[0] = cc0;
    numBitsCharCount[1] = cc1;
    numBitsCharCount[2] = cc2;
}

int QrSegment::Mode::modeBits() const {
    return modeBits_;
}

int QrSegment::Mode::numCharCountBits(int ver) const {
    if      ( 1 <= ver && ver <=  9)  return numBitsCharCount[0];
    else if (10 <= ver && ver <= 26)  return numBitsCharCount[1];
    else if (27 <= ver && ver <= 40)  return numBitsCharCount[2];
    else  throw std::domain_error("Version number out of range");
}


/*---- Class QrSegment ----*/

QrSegment QrSegment::makeBytes(const vector<uint8_t> &data) {
    if (data.size() > static_cast<unsigned int>(INT_MAX))
        throw std::length_error("Data too long");
    vector<bool> bb;
    for (uint8_t b : data) {
        for (int i = 7; i >= 0; i--)
            bb.push_back(((b >> i) & 1) != 0);
    }
    return QrSegment(Mode::BYTE, static_cast<int>(data.size()), std::move(bb));
}

QrSegment QrSegment::makeNumeric(const char *digits) {
    if (!isNumeric(digits))
        throw std::domain_error("String contains non-numeric characters");
    vector<bool> bb;
    int accumData = 0;
    int accumCount = 0;
    int charCount = 0;
    for (; *digits != '\0'; digits++, charCount++) {
        accumData = accumData * 10 + (*digits - '0');
        accumCount++;
        if (accumCount == 3) {
            for (int i = 9; i >= 0; i--)
                bb.push_back(((accumData >> i) & 1) != 0);
            accumData = 0;
            accumCount = 0;
        }
    }
    if (accumCount > 0) {
        int numBits = accumCount * 3 + 1;
        for (int i = numBits - 1; i >= 0; i--)
            bb.push_back(((accumData >> i) & 1) != 0);
    }
    return QrSegment(Mode::NUMERIC, charCount, std::move(bb));
}

QrSegment QrSegment::makeAlphanumeric(const char *text) {
    if (!isAlphanumeric(text))
        throw std::domain_error("String contains unencodable characters in alphanumeric mode");
    static const char *ALPHANUMERIC_CHARSET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";
    vector<bool> bb;
    int accumData = 0;
    int accumCount = 0;
    int charCount = 0;
    for (; *text != '\0'; text++, charCount++) {
        const char *temp = std::strchr(ALPHANUMERIC_CHARSET, *text);
        accumData = accumData * 45 + static_cast<int>(temp - ALPHANUMERIC_CHARSET);
        accumCount++;
        if (accumCount == 2) {
            for (int i = 10; i >= 0; i--)
                bb.push_back(((accumData >> i) & 1) != 0);
            accumData = 0;
            accumCount = 0;
        }
    }
    if (accumCount > 0) {
        for (int i = 5; i >= 0; i--)
            bb.push_back(((accumData >> i) & 1) != 0);
    }
    return QrSegment(Mode::ALPHANUMERIC, charCount, std::move(bb));
}

vector<QrSegment> QrSegment::makeSegments(const char *text) {
    vector<QrSegment> result;
    if (*text == '\0')
        ;
    else if (isNumeric(text))
        result.push_back(makeNumeric(text));
    else if (isAlphanumeric(text))
        result.push_back(makeAlphanumeric(text));
    else {
        vector<uint8_t> bytes;
        for (; *text != '\0'; text++)
            bytes.push_back(static_cast<uint8_t>(*text));
        result.push_back(makeBytes(bytes));
    }
    return result;
}

QrSegment QrSegment::makeEci(long assignVal) {
    vector<bool> bb;
    if (assignVal < 0)
        throw std::domain_error("ECI assignment value out of range");
    else if (assignVal < (1 << 7)) {
        for (int i = 7; i >= 0; i--)
            bb.push_back(((assignVal >> i) & 1) != 0);
    } else if (assignVal < (1 << 14)) {
        bb.push_back(true);
        bb.push_back(false);
        for (int i = 13; i >= 0; i--)
            bb.push_back(((assignVal >> i) & 1) != 0);
    } else if (assignVal < 1000000L) {
        bb.push_back(true);
        bb.push_back(true);
        bb.push_back(false);
        for (int i = 20; i >= 0; i--)
            bb.push_back(((assignVal >> i) & 1) != 0);
    } else
        throw std::domain_error("ECI assignment value out of range");
    return QrSegment(Mode::ECI, 0, std::move(bb));
}

bool QrSegment::isNumeric(const char *text) {
    for (; *text != '\0'; text++) {
        if (*text < '0' || *text > '9')
            return false;
    }
    return true;
}

bool QrSegment::isAlphanumeric(const char *text) {
    static const char *ALPHANUMERIC_CHARSET = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:";
    for (; *text != '\0'; text++) {
        if (std::strchr(ALPHANUMERIC_CHARSET, *text) == nullptr)
            return false;
    }
    return true;
}

QrSegment::QrSegment(const Mode &md, int numCh, const vector<bool> &dt) :
    mode(&md), numChars(numCh), data(dt) {
    if (numCh < 0)
        throw std::domain_error("Invalid value");
}

QrSegment::QrSegment(const Mode &md, int numCh, vector<bool> &&dt) :
    mode(&md), numChars(numCh), data(std::move(dt)) {
    if (numCh < 0)
        throw std::domain_error("Invalid value");
}

const QrSegment::Mode &QrSegment::getMode() const {
    return *mode;
}

int QrSegment::getNumChars() const {
    return numChars;
}

const vector<bool> &QrSegment::getData() const {
    return data;
}

int QrSegment::getTotalBits(const vector<QrSegment> &segs, int version) {
    int result = 0;
    for (const QrSegment &seg : segs) {
        int ccbits = seg.mode->numCharCountBits(version);
        if (seg.numChars >= (1 << ccbits))
            return -1;
        if (4 + ccbits > INT_MAX - result)
            return -1;
        result += 4 + ccbits;
        if (static_cast<size_t>(seg.data.size()) > static_cast<size_t>(INT_MAX - result))
            return -1;
        result += static_cast<int>(seg.data.size());
    }
    return result;
}


/*---- Class QrCode ----*/

QrCode QrCode::encodeText(const char *text, Ecc ecl) {
    vector<QrSegment> segs = QrSegment::makeSegments(text);
    return encodeSegments(segs, ecl);
}

QrCode QrCode::encodeBinary(const vector<uint8_t> &data, Ecc ecl) {
    vector<QrSegment> segs{QrSegment::makeBytes(data)};
    return encodeSegments(segs, ecl);
}

QrCode QrCode::encodeSegments(const vector<QrSegment> &segs, Ecc ecl,
        int minVersion, int maxVersion, int mask, bool boostEcl) {
    if (!(MIN_VERSION <= minVersion && minVersion <= maxVersion && maxVersion <= MAX_VERSION) || mask < -1 || mask > 7)
        throw std::invalid_argument("Invalid value");

    int version, dataUsedBits;
    for (version = minVersion; ; version++) {
        int dataCapacityBits = getNumDataCodewords(version, ecl) * 8;
        dataUsedBits = QrSegment::getTotalBits(segs, version);
        if (dataUsedBits != -1 && dataUsedBits <= dataCapacityBits)
            break;
        if (version >= maxVersion) {
            std::ostringstream sb;
            if (dataUsedBits == -1)
                sb << "Segment too long";
            else {
                sb << "Data length = " << dataUsedBits << " bits, ";
                sb << "Max capacity = " << dataCapacityBits << " bits";
            }
            throw std::length_error(sb.str());
        }
    }
    assert(dataUsedBits != -1);

    if (boostEcl) {
        if (dataUsedBits <= getNumDataCodewords(version, Ecc::MEDIUM  ) * 8)  ecl = Ecc::MEDIUM;
        if (dataUsedBits <= getNumDataCodewords(version, Ecc::QUARTILE) * 8)  ecl = Ecc::QUARTILE;
        if (dataUsedBits <= getNumDataCodewords(version, Ecc::HIGH    ) * 8)  ecl = Ecc::HIGH;
    }

    vector<bool> bb;
    for (const QrSegment &seg : segs) {
        int modeBits = seg.getMode().modeBits();
        for (int i = 3; i >= 0; i--)
            bb.push_back(((modeBits >> i) & 1) != 0);
        int numCharCountBits = seg.getMode().numCharCountBits(version);
        int numChars = seg.getNumChars();
        for (int i = numCharCountBits - 1; i >= 0; i--)
            bb.push_back(((numChars >> i) & 1) != 0);
        for (bool b : seg.getData())
            bb.push_back(b);
    }
    assert(static_cast<int>(bb.size()) == dataUsedBits);

    int dataCapacityBits = getNumDataCodewords(version, ecl) * 8;
    assert(static_cast<int>(bb.size()) <= dataCapacityBits);

    // Add terminator
    for (int i = 0; i < 4 && static_cast<int>(bb.size()) < dataCapacityBits; i++)
        bb.push_back(false);

    // Pad to byte boundary
    for (int i = 0; static_cast<int>(bb.size()) % 8 != 0; i++)
        bb.push_back(false);

    // Pad with alternating bytes
    for (uint8_t padByte = 0xEC; static_cast<int>(bb.size()) < dataCapacityBits; padByte ^= 0xEC ^ 0x11)
        for (int i = 7; i >= 0; i--)
            bb.push_back(((padByte >> i) & 1) != 0);
    assert(static_cast<int>(bb.size()) == dataCapacityBits);

    // Pack bits into bytes
    vector<uint8_t> dataCodewords(static_cast<size_t>(bb.size() / 8));
    for (size_t i = 0; i < bb.size(); i++)
        dataCodewords.at(i >> 3) |= (bb.at(i) ? 1 : 0) << (7 - static_cast<int>(i & 7));

    // Select mask
    QrCode result(version, ecl, dataCodewords, mask);
    return result;
}

QrCode::QrCode(int ver, Ecc ecl, const vector<uint8_t> &dataCodewords, int msk) :
    version(ver),
    size(ver * 4 + 17),
    errorCorrectionLevel(ecl),
    mask(0),
    modules(static_cast<size_t>(size), vector<bool>(static_cast<size_t>(size))),
    isFunction(static_cast<size_t>(size), vector<bool>(static_cast<size_t>(size))) {

    if (ver < MIN_VERSION || ver > MAX_VERSION)
        throw std::domain_error("Version value out of range");
    if (msk < -1 || msk > 7)
        throw std::domain_error("Mask value out of range");

    drawFunctionPatterns();
    const vector<uint8_t> allCodewords = addEccAndInterleave(dataCodewords);
    drawCodewords(allCodewords);

    if (msk == -1) {
        long minPenalty = LONG_MAX;
        for (int i = 0; i < 8; i++) {
            applyMask(i);
            drawFormatBits(i);
            long penalty = getPenaltyScore();
            if (penalty < minPenalty) {
                msk = i;
                minPenalty = penalty;
            }
            applyMask(i);  // undo
        }
    }
    assert(0 <= msk && msk <= 7);
    mask = msk;
    applyMask(msk);
    drawFormatBits(msk);

    isFunction.clear();
    isFunction.shrink_to_fit();
}

int QrCode::getVersion() const {
    return version;
}

int QrCode::getSize() const {
    return size;
}

QrCode::Ecc QrCode::getErrorCorrectionLevel() const {
    return errorCorrectionLevel;
}

int QrCode::getMask() const {
    return mask;
}

bool QrCode::getModule(int x, int y) const {
    return 0 <= x && x < size && 0 <= y && y < size && hasDark(y, x);
}

bool QrCode::hasDark(int y, int x) const {
    return modules.at(static_cast<size_t>(y)).at(static_cast<size_t>(x));
}

void QrCode::drawFunctionPatterns() {
    // Finder patterns + separators
    for (int i = 0; i < size; i++) {
        setFunctionModule(6, i, i % 2 == 0);
        setFunctionModule(i, 6, i % 2 == 0);
    }
    drawFinderPattern(3, 3);
    drawFinderPattern(size - 4, 3);
    drawFinderPattern(3, size - 4);

    // Alignment patterns
    const vector<int> alignPatPos = getAlignmentPatternPositions();
    size_t numAlign = alignPatPos.size();
    for (size_t i = 0; i < numAlign; i++) {
        for (size_t j = 0; j < numAlign; j++) {
            if (!((i == 0 && j == 0) || (i == 0 && j == numAlign - 1) || (i == numAlign - 1 && j == 0)))
                drawAlignmentPattern(alignPatPos.at(i), alignPatPos.at(j));
        }
    }

    drawFormatBits(0);
    drawVersion();
}

void QrCode::drawFormatBits(int msk) {
    int data = static_cast<int>(errorCorrectionLevel) ^ 1;
    data = (data << 3) | msk;
    int rem = data;
    for (int i = 0; i < 10; i++)
        rem = (rem << 1) ^ ((rem >> 9) * 0x537);
    int bits = (data << 10 | rem) ^ 0x5412;
    assert(bits >> 15 == 0);

    for (int i = 0; i <= 5; i++)
        setFunctionModule(8, i, getBit(bits, i));
    setFunctionModule(8, 7, getBit(bits, 6));
    setFunctionModule(8, 8, getBit(bits, 7));
    setFunctionModule(7, 8, getBit(bits, 8));
    for (int i = 9; i < 15; i++)
        setFunctionModule(14 - i, 8, getBit(bits, i));

    for (int i = 0; i < 8; i++)
        setFunctionModule(size - 1 - i, 8, getBit(bits, i));
    for (int i = 8; i < 15; i++)
        setFunctionModule(8, size - 15 + i, getBit(bits, i));
    setFunctionModule(8, size - 8, true);
}

void QrCode::drawVersion() {
    if (version < 7)
        return;
    int rem = version;
    for (int i = 0; i < 12; i++)
        rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
    long bits = (static_cast<long>(version) << 12) | rem;
    assert(bits >> 18 == 0);

    for (int i = 0; i < 18; i++) {
        bool bit = getBit(static_cast<int>(bits), i);
        int a = size - 11 + i % 3;
        int b = i / 3;
        setFunctionModule(a, b, bit);
        setFunctionModule(b, a, bit);
    }
}

void QrCode::drawFinderPattern(int x, int y) {
    for (int dy = -4; dy <= 4; dy++) {
        for (int dx = -4; dx <= 4; dx++) {
            int dist = std::max(std::abs(dx), std::abs(dy));
            int xx = x + dx, yy = y + dy;
            if (0 <= xx && xx < size && 0 <= yy && yy < size)
                setFunctionModule(xx, yy, dist != 2 && dist != 4);
        }
    }
}

void QrCode::drawAlignmentPattern(int x, int y) {
    for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++)
            setFunctionModule(x + dx, y + dy, std::max(std::abs(dx), std::abs(dy)) != 1);
    }
}

void QrCode::setFunctionModule(int x, int y, bool isDark) {
    modules.at(static_cast<size_t>(y)).at(static_cast<size_t>(x)) = isDark;
    isFunction.at(static_cast<size_t>(y)).at(static_cast<size_t>(x)) = true;
}

vector<uint8_t> QrCode::addEccAndInterleave(const vector<uint8_t> &data) const {
    if (data.size() != static_cast<unsigned int>(getNumDataCodewords(version, errorCorrectionLevel)))
        throw std::invalid_argument("Invalid argument");

    int numBlocks = NUM_ERROR_CORRECTION_BLOCKS[static_cast<int>(errorCorrectionLevel)][version];
    int blockEccLen = ECC_CODEWORDS_PER_BLOCK  [static_cast<int>(errorCorrectionLevel)][version];
    int rawCodewords = getNumRawDataModules(version) / 8;
    int numShortBlocks = numBlocks - rawCodewords % numBlocks;
    int shortBlockLen = rawCodewords / numBlocks;

    vector<vector<uint8_t>> blocks;
    const vector<uint8_t> rsDiv = reedSolomonComputeDivisor(blockEccLen);
    for (int i = 0, k = 0; i < numBlocks; i++) {
        vector<uint8_t> dat(data.cbegin() + k,
            data.cbegin() + (k + shortBlockLen - blockEccLen + (i < numShortBlocks ? 0 : 1)));
        k += static_cast<int>(dat.size());
        const vector<uint8_t> ecc = reedSolomonComputeRemainder(dat, rsDiv);
        if (i < numShortBlocks)
            dat.push_back(0);
        dat.insert(dat.end(), ecc.cbegin(), ecc.cend());
        blocks.push_back(std::move(dat));
    }

    vector<uint8_t> result;
    for (size_t i = 0; i < blocks.at(0).size(); i++) {
        for (size_t j = 0; j < blocks.size(); j++) {
            if (i != static_cast<size_t>(shortBlockLen - blockEccLen) || j >= static_cast<size_t>(numShortBlocks))
                result.push_back(blocks.at(j).at(i));
        }
    }
    assert(result.size() == static_cast<size_t>(rawCodewords));
    return result;
}

void QrCode::drawCodewords(const vector<uint8_t> &data) {
    if (data.size() != static_cast<size_t>(getNumRawDataModules(version) / 8))
        throw std::invalid_argument("Invalid argument");

    size_t i = 0;
    for (int right = size - 1; right >= 1; right -= 2) {
        if (right == 6)
            right = 5;
        for (int vert = 0; vert < size; vert++) {
            for (int j = 0; j < 2; j++) {
                size_t x = static_cast<size_t>(right - j);
                bool upward = ((right + 1) & 2) == 0;
                size_t y = static_cast<size_t>(upward ? size - 1 - vert : vert);
                if (!isFunction.at(y).at(x) && i < data.size() * 8) {
                    modules.at(y).at(x) = getBit(data.at(i >> 3), 7 - static_cast<int>(i & 7));
                    i++;
                }
            }
        }
    }
    assert(i == data.size() * 8);
}

void QrCode::applyMask(int msk) {
    if (msk < 0 || msk > 7)
        throw std::domain_error("Mask value out of range");
    for (size_t y = 0; y < static_cast<size_t>(size); y++) {
        for (size_t x = 0; x < static_cast<size_t>(size); x++) {
            bool invert;
            switch (msk) {
                case 0:  invert = (static_cast<int>(x + y)) % 2 == 0;                                  break;
                case 1:  invert = static_cast<int>(y) % 2 == 0;                                        break;
                case 2:  invert = static_cast<int>(x) % 3 == 0;                                        break;
                case 3:  invert = (static_cast<int>(x + y)) % 3 == 0;                                  break;
                case 4:  invert = (static_cast<int>(x) / 3 + static_cast<int>(y) / 2) % 2 == 0;       break;
                case 5:  invert = static_cast<int>(x * y) % 2 + static_cast<int>(x * y) % 3 == 0;     break;
                case 6:  invert = (static_cast<int>(x * y) % 2 + static_cast<int>(x * y) % 3) % 2 == 0; break;
                case 7:  invert = (static_cast<int>(x + y) % 2 + static_cast<int>(x * y) % 3) % 2 == 0; break;
                default:  throw std::logic_error("Unreachable");
            }
            modules[y][x] = modules[y][x] ^ (invert & !isFunction[y][x]);
        }
    }
}

long QrCode::getPenaltyScore() const {
    long result = 0;

    // Rule 1: 5+ in a row same color
    for (int y = 0; y < size; y++) {
        bool runColor = false;
        int runX = 0;
        std::array<int,7> runHistory = {};
        for (int x = 0; x < size; x++) {
            if (hasDark(y, x) == runColor) {
                runX++;
                if (runX == 5)
                    result += PENALTY_N1;
                else if (runX > 5)
                    result++;
            } else {
                finderPenaltyAddHistory(runX, runHistory);
                if (!runColor)
                    result += finderPenaltyCountPatterns(runHistory) * PENALTY_N3;
                runColor = hasDark(y, x);
                runX = 1;
            }
        }
        result += finderPenaltyTerminateAndCount(runColor, runX, runHistory) * PENALTY_N3;
    }
    for (int x = 0; x < size; x++) {
        bool runColor = false;
        int runY = 0;
        std::array<int,7> runHistory = {};
        for (int y = 0; y < size; y++) {
            if (hasDark(y, x) == runColor) {
                runY++;
                if (runY == 5)
                    result += PENALTY_N1;
                else if (runY > 5)
                    result++;
            } else {
                finderPenaltyAddHistory(runY, runHistory);
                if (!runColor)
                    result += finderPenaltyCountPatterns(runHistory) * PENALTY_N3;
                runColor = hasDark(y, x);
                runY = 1;
            }
        }
        result += finderPenaltyTerminateAndCount(runColor, runY, runHistory) * PENALTY_N3;
    }

    // Rule 2: 2x2 squares
    for (int y = 0; y < size - 1; y++) {
        for (int x = 0; x < size - 1; x++) {
            bool color = hasDark(y, x);
            if (color == hasDark(y, x + 1) && color == hasDark(y + 1, x) && color == hasDark(y + 1, x + 1))
                result += PENALTY_N2;
        }
    }

    // Rule 4: proportion of dark modules
    int dark = 0;
    for (const vector<bool> &row : modules) {
        for (bool color : row) {
            if (color)
                dark++;
        }
    }
    int total = size * size;
    int k = static_cast<int>((std::abs(dark * 20L - total * 10L) + total - 1) / total) - 1;
    assert(0 <= k && k <= 9);
    result += k * PENALTY_N4;
    assert(0 <= result && result <= 2568888L);
    return result;
}

vector<int> QrCode::getAlignmentPatternPositions() const {
    if (version == 1)
        return {};
    int numAlign = version / 7 + 2;
    int step = (version == 32) ? 26 :
        (version * 4 + numAlign * 2 + 1) / (numAlign * 2 - 2) * 2;
    vector<int> result;
    for (int i = 0, pos = size - 7; i < numAlign - 1; i++, pos -= step)
        result.insert(result.begin(), pos);
    result.insert(result.begin(), 6);
    return result;
}

int QrCode::getNumRawDataModules(int ver) {
    if (ver < MIN_VERSION || ver > MAX_VERSION)
        throw std::domain_error("Version number out of range");
    int result = (16 * ver + 128) * ver + 64;
    if (ver >= 2) {
        int numAlign = ver / 7 + 2;
        result -= (25 * numAlign - 10) * numAlign - 55;
        if (ver >= 7)
            result -= 36;
    }
    assert(208 <= result && result <= 29648);
    return result;
}

int QrCode::getNumDataCodewords(int ver, Ecc ecl) {
    return getNumRawDataModules(ver) / 8
        - ECC_CODEWORDS_PER_BLOCK    [static_cast<int>(ecl)][ver]
        * NUM_ERROR_CORRECTION_BLOCKS[static_cast<int>(ecl)][ver];
}

vector<uint8_t> QrCode::reedSolomonComputeDivisor(int degree) {
    if (degree < 1 || degree > 255)
        throw std::domain_error("Degree out of range");
    vector<uint8_t> result(static_cast<size_t>(degree));
    result.at(result.size() - 1) = 1;

    uint8_t root = 1;
    for (int i = 0; i < degree; i++) {
        for (size_t j = 0; j < result.size(); j++) {
            result.at(j) = reedSolomonMultiply(result.at(j), root);
            if (j + 1 < result.size())
                result.at(j) ^= result.at(j + 1);
        }
        root = reedSolomonMultiply(root, 0x02);
    }
    return result;
}

vector<uint8_t> QrCode::reedSolomonComputeRemainder(const vector<uint8_t> &data, const vector<uint8_t> &divisor) {
    vector<uint8_t> result(divisor.size());
    for (uint8_t b : data) {
        uint8_t factor = b ^ result.at(0);
        result.erase(result.begin());
        result.push_back(0);
        for (size_t i = 0; i < result.size(); i++)
            result.at(i) ^= reedSolomonMultiply(divisor.at(i), factor);
    }
    return result;
}

uint8_t QrCode::reedSolomonMultiply(uint8_t x, uint8_t y) {
    int z = 0;
    for (int i = 7; i >= 0; i--) {
        z = (z << 1) ^ ((z >> 7) * 0x11D);
        z ^= ((y >> i) & 1) * x;
    }
    assert(z >> 8 == 0);
    return static_cast<uint8_t>(z);
}

int QrCode::finderPenaltyCountPatterns(const std::array<int,7> &runHistory) const {
    int n = runHistory[1];
    assert(n <= size * 3);
    bool core = n > 0 && runHistory[2] == n && runHistory[3] == n * 3 && runHistory[4] == n && runHistory[5] == n;
    return (core && runHistory[0] >= n * 4 && runHistory[6] >= n ? 1 : 0)
         + (core && runHistory[6] >= n * 4 && runHistory[0] >= n ? 1 : 0);
}

int QrCode::finderPenaltyTerminateAndCount(bool currentRunColor, int currentRunLength, std::array<int,7> &runHistory) const {
    if (currentRunColor) {
        finderPenaltyAddHistory(currentRunLength, runHistory);
        currentRunLength = 0;
    }
    currentRunLength += size;
    finderPenaltyAddHistory(currentRunLength, runHistory);
    return finderPenaltyCountPatterns(runHistory);
}

void QrCode::finderPenaltyAddHistory(int currentRunLength, std::array<int,7> &runHistory) const {
    if (runHistory[0] == 0)
        currentRunLength += size;
    std::copy_backward(runHistory.cbegin(), runHistory.cend() - 1, runHistory.end());
    runHistory[0] = currentRunLength;
}

bool QrCode::getBit(int x, int i) {
    return ((x >> i) & 1) != 0;
}


/*---- Tables of constants ----*/

const int16_t QrCode::ECC_CODEWORDS_PER_BLOCK[4][41] = {
    // Version: (index 0 is unset), 1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40  Error correction level
    {-1,  7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30},  // Low
    {-1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28},  // Medium
    {-1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30},  // Quartile
    {-1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30},  // High
};

const int8_t QrCode::NUM_ERROR_CORRECTION_BLOCKS[4][41] = {
    // Version: (index 0 is unset), 1, 2, 3, 4, 5, 6, 7, 8, 9,10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40  Error correction level
    {-1, 1, 1, 1, 1, 1, 2, 2, 2, 2,  4,  4,  4,  4,  4,  6,  6,  6,  6,  7,  8,  8,  9,  9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25},  // Low
    {-1, 1, 1, 1, 2, 2, 4, 4, 4, 5,  5,  5,  8,  9,  9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49},  // Medium
    {-1, 1, 1, 2, 2, 4, 4, 6, 6, 8,  8,  8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68},  // Quartile
    {-1, 1, 1, 2, 4, 4, 4, 5, 6, 8,  8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81},  // High
};

}  // namespace qrcodegen
