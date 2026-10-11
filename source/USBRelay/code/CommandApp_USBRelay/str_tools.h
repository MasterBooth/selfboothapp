#pragma once

#include <string>
#include <Windows.h>

std::string WChar2Ansi(LPCWSTR pwszSrc);

std::wstring Ansi2WChar(LPCSTR pszSrc);