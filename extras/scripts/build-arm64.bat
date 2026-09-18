@echo off
setlocal EnableExtensions

set "ROOT=%~dp0..\.."
set "SDK_VERSION=10.0.22621.0"
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

if not exist "%VSWHERE%" (
	echo Visual Studio Installer's vswhere.exe was not found.
	exit /b 1
)

set "VS_ROOT="
for /f "usebackq tokens=*" %%I in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.ATL.ARM64 -property installationPath`) do set "VS_ROOT=%%I"
if not defined VS_ROOT (
	echo Visual Studio with the ARM64 ATL component was not found.
	exit /b 1
)

call "%VS_ROOT%\VC\Auxiliary\Build\vcvarsall.bat" amd64_arm64 %SDK_VERSION% -vcvars_ver=14.29
if errorlevel 1 exit /b 1

for %%T in (cmake.exe msbuild.exe nmake.exe) do (
	where %%T >nul 2>nul
	if errorlevel 1 (
		echo %%T was not found after initializing Visual Studio.
		exit /b 1
	)
)

set "TARGET=%~1"
if not defined TARGET set "TARGET=all"

if /i "%TARGET%"=="all" goto all
if /i "%TARGET%"=="dependencies" goto dependencies
if /i "%TARGET%"=="app" goto app
if /i "%TARGET%"=="libwebp" goto libwebp
if /i "%TARGET%"=="libjpeg" goto libjpeg
if /i "%TARGET%"=="libpng" goto libpng
if /i "%TARGET%"=="libjxl" goto libjxl
if /i "%TARGET%"=="libraw" goto libraw
if /i "%TARGET%"=="lcms2" goto lcms2
if /i "%TARGET%"=="heifavif" goto heifavif

echo Usage: %~nx0 [all^|dependencies^|app^|libwebp^|libjpeg^|libpng^|libjxl^|libraw^|lcms2^|heifavif]
exit /b 2

:all
call :dependencies
if errorlevel 1 exit /b 1
goto app

:dependencies
call :libwebp
if errorlevel 1 exit /b 1
call :libjpeg
if errorlevel 1 exit /b 1
call :libpng
if errorlevel 1 exit /b 1
call :libjxl
if errorlevel 1 exit /b 1
call :libraw
if errorlevel 1 exit /b 1
call :lcms2
if errorlevel 1 exit /b 1
call :heifavif
exit /b %errorlevel%

:prepare_output
for %%D in (
	"%ROOT%\src\JPEGView\libwebp\libarm64"
	"%ROOT%\src\JPEGView\libjpeg-turbo\libarm64"
	"%ROOT%\src\JPEGView\libpng-apng\libarm64"
	"%ROOT%\src\JPEGView\libjxl\libarm64"
	"%ROOT%\src\JPEGView\libjxl\binarm64"
	"%ROOT%\src\JPEGView\libheif\libarm64"
	"%ROOT%\src\JPEGView\libheif\binarm64"
	"%ROOT%\src\JPEGView\libavif\libarm64"
	"%ROOT%\src\JPEGView\libavif\binarm64"
	"%ROOT%\src\JPEGView\lcms2\libarm64"
	"%ROOT%\src\JPEGView\lcms2\binarm64"
	"%ROOT%\src\JPEGView\libraw\libarm64"
	"%ROOT%\src\JPEGView\libraw\binarm64"
) do if not exist "%%~D" mkdir "%%~D"
exit /b 0

:libwebp
call :prepare_output
set "OUT=%~dp0libwebp-arm64"
if exist "%OUT%" rmdir /s /q "%OUT%"
pushd "%ROOT%\extras\third_party\libwebp"
nmake.exe /f Makefile.vc ARCH=ARM64 CFG=release-static RTLIBCFG=static OBJDIR="%OUT%"
if errorlevel 1 exit /b 1
popd
copy /y "%OUT%\release-static\ARM64\lib\libwebp.lib" "%ROOT%\src\JPEGView\libwebp\libarm64\"
if errorlevel 1 exit /b 1
copy /y "%OUT%\release-static\ARM64\lib\libwebpdemux.lib" "%ROOT%\src\JPEGView\libwebp\libarm64\"
exit /b %errorlevel%

:libjpeg
call :prepare_output
set "OUT=%~dp0libjpeg-turbo\arm64"
if exist "%OUT%" rmdir /s /q "%OUT%"
cmake.exe -S "%ROOT%\extras\third_party\libjpeg-turbo" -B "%OUT%" -A ARM64 -T v142 -DCMAKE_SYSTEM_VERSION=%SDK_VERSION% -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DWITH_SIMD=OFF
if errorlevel 1 exit /b 1
cmake.exe --build "%OUT%" --config Release --target turbojpeg-static
if errorlevel 1 exit /b 1
copy /y "%OUT%\Release\turbojpeg-static.lib" "%ROOT%\src\JPEGView\libjpeg-turbo\libarm64\"
exit /b %errorlevel%

:libpng
call :prepare_output
set "ZOUT=%~dp0zlib-arm64"
if exist "%ZOUT%" rmdir /s /q "%ZOUT%"
cmake.exe -S "%ROOT%\extras\third_party\libpng-apng.src-patch\zlib" -B "%ZOUT%" -A ARM64 -T v142 -DCMAKE_SYSTEM_VERSION=%SDK_VERSION% -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded
if errorlevel 1 exit /b 1
cmake.exe --build "%ZOUT%" --config Release --target zlibstatic
if errorlevel 1 exit /b 1
copy /y "%ROOT%\extras\third_party\libpng-apng.src-patch\zlib\zlib.h" "%ZOUT%\zlib.h"
if errorlevel 1 exit /b 1

set "OUT=%~dp0libpng-arm64"
if exist "%OUT%" rmdir /s /q "%OUT%"
cmake.exe -S "%ROOT%\extras\third_party\libpng-apng.src-patch\libpng" -B "%OUT%" -A ARM64 -T v142 -DCMAKE_SYSTEM_VERSION=%SDK_VERSION% -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded -DPNG_SHARED=OFF -DPNG_TESTS=OFF -DZLIB_LIBRARY="%ZOUT%\Release\zlibstatic.lib" -DZLIB_INCLUDE_DIR="%ZOUT%"
if errorlevel 1 exit /b 1
set "_CL_=/MT"
cmake.exe --build "%OUT%" --config Release --target png_static
set "_CL_="
if errorlevel 1 exit /b 1
copy /y "%OUT%\Release\libpng16_static.lib" "%ROOT%\src\JPEGView\libpng-apng\libarm64\libpng16.lib"
if errorlevel 1 exit /b 1
copy /y "%ZOUT%\Release\zlibstatic.lib" "%ROOT%\src\JPEGView\libpng-apng\libarm64\zlib.lib"
exit /b %errorlevel%

:libjxl
call :prepare_output
set "OUT=%~dp0libjxl\arm64"
if exist "%OUT%" rmdir /s /q "%OUT%"
cmake.exe -S "%ROOT%\extras\third_party\libjxl" -B "%OUT%" -A ARM64 -T v142 -DCMAKE_SYSTEM_VERSION=%SDK_VERSION% -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DBUILD_TESTING=OFF
if errorlevel 1 exit /b 1
cmake.exe --build "%OUT%" --config Release --target jxl_dec jxl_threads
if errorlevel 1 exit /b 1
copy /y "%OUT%\Release\jxl*.dll" "%ROOT%\src\JPEGView\libjxl\binarm64\"
if errorlevel 1 exit /b 1
copy /y "%OUT%\third_party\brotli\Release\brotli*.dll" "%ROOT%\src\JPEGView\libjxl\binarm64\"
if errorlevel 1 exit /b 1
copy /y "%OUT%\lib\Release\jxl*.lib" "%ROOT%\src\JPEGView\libjxl\libarm64\"
exit /b %errorlevel%

:libraw
call :prepare_output
pushd "%ROOT%\extras\third_party\LibRaw"
(
	echo COPT_OPT=/DUSE_X3FTOOLS /DUSE_6BY9RPI /DUSE_OLD_VIDEOCAMS
	type Makefile.msvc
) > Makefile.portpilot-arm64
nmake.exe -f Makefile.portpilot-arm64 clean
if errorlevel 1 exit /b 1
nmake.exe -f Makefile.portpilot-arm64
if errorlevel 1 exit /b 1
copy /y "lib\libraw.lib" "%ROOT%\src\JPEGView\libraw\libarm64\"
if errorlevel 1 exit /b 1
copy /y "bin\libraw.dll" "%ROOT%\src\JPEGView\libraw\binarm64\"
if errorlevel 1 exit /b 1
del /q Makefile.portpilot-arm64
popd
exit /b 0

:lcms2
call :prepare_output
set "OUT=%~dp0lcms2-arm64"
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%"
msbuild.exe /nologo /m /t:Rebuild /p:Platform=ARM64 /p:Configuration=Release /p:WindowsTargetPlatformVersion=%SDK_VERSION% /p:OutDir="%OUT%\\" /p:IntDir="%OUT%\obj\\" "%ROOT%\extras\third_party\Little-CMS\Projects\VC2019\lcms2_DLL\lcms2_DLL.vcxproj" /v:minimal
if errorlevel 1 exit /b 1
copy /y "%OUT%\lcms2.lib" "%ROOT%\src\JPEGView\lcms2\libarm64\"
if errorlevel 1 exit /b 1
copy /y "%OUT%\lcms2.dll" "%ROOT%\src\JPEGView\lcms2\binarm64\"
exit /b %errorlevel%

:heifavif
call :prepare_output
set "PYTHON_EXE=%JPEGVIEW_PYTHON%"
if not defined PYTHON_EXE for /f "delims=" %%P in ('where python.exe 2^>nul') do if not defined PYTHON_EXE set "PYTHON_EXE=%%P"
if not defined PYTHON_EXE for /f "delims=" %%P in ('dir /b /s /o:n "%LocalAppData%\Programs\Python\Python*\python.exe" 2^>nul') do set "PYTHON_EXE=%%P"
if not defined PYTHON_EXE (
	echo Python 3 was not found. Set JPEGVIEW_PYTHON to its python.exe path.
	exit /b 1
)

set "OUT=%~dp0libheif-libavif-arm64"
set "VENV=%~dp0venv-meson-arm64"
if not exist "%VENV%\Scripts\python.exe" "%PYTHON_EXE%" -m venv "%VENV%"
if errorlevel 1 exit /b 1
call "%VENV%\Scripts\activate.bat"
python.exe -m pip install --disable-pip-version-check --quiet --upgrade pip meson ninja
if errorlevel 1 exit /b 1

set "DAV1D_BUILD=%OUT%\dav1d\build"
set "DAV1D_DIST=%OUT%\dav1d\dist"
if not exist "%DAV1D_DIST%\bin\dav1d.dll" (
	meson setup --cross-file "%~dp0dav1d-arm64.ini" --buildtype release --prefix "%DAV1D_DIST%" -Denable_asm=false -Denable_tests=false -Denable_tools=false "%DAV1D_BUILD%" "%ROOT%\extras\third_party\libheif\dav1d"
	if errorlevel 1 exit /b 1
	ninja.exe -C "%DAV1D_BUILD%"
	if errorlevel 1 exit /b 1
	ninja.exe -C "%DAV1D_BUILD%" install
	if errorlevel 1 exit /b 1
)
copy /y "%DAV1D_DIST%\bin\dav1d.dll" "%ROOT%\src\JPEGView\libavif\binarm64\"
if errorlevel 1 exit /b 1

set "AVIF_BUILD=%OUT%\libavif"
if not exist "%AVIF_BUILD%\Release\avif.dll" (
	cmake.exe -S "%ROOT%\extras\third_party\libavif" -B "%AVIF_BUILD%" -A ARM64 -T v142 -DCMAKE_SYSTEM_VERSION=%SDK_VERSION% -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DAVIF_CODEC_DAV1D=ON -DDAV1D_LIBRARY="%DAV1D_DIST%\lib\dav1d.lib" -DDAV1D_INCLUDE_DIR="%DAV1D_DIST%\include"
	if errorlevel 1 exit /b 1
	cmake.exe --build "%AVIF_BUILD%" --config Release
	if errorlevel 1 exit /b 1
)
copy /y "%AVIF_BUILD%\Release\avif.dll" "%ROOT%\src\JPEGView\libavif\binarm64\"
if errorlevel 1 exit /b 1
copy /y "%AVIF_BUILD%\Release\avif.lib" "%ROOT%\src\JPEGView\libavif\libarm64\"
if errorlevel 1 exit /b 1

set "LIBDE_BUILD=%OUT%\libde265"
if exist "%LIBDE_BUILD%" rmdir /s /q "%LIBDE_BUILD%"
cmake.exe -S "%ROOT%\extras\third_party\libheif\libde265" -B "%LIBDE_BUILD%" -A ARM64 -T v142 -DCMAKE_SYSTEM_VERSION=%SDK_VERSION% -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DDISABLE_SSE=ON -DENABLE_SDL=OFF
if errorlevel 1 exit /b 1
cmake.exe --build "%LIBDE_BUILD%" --config Release --target de265
if errorlevel 1 exit /b 1
copy /y "%LIBDE_BUILD%\libde265\Release\libde265.dll" "%ROOT%\src\JPEGView\libheif\binarm64\"
if errorlevel 1 exit /b 1
copy /y "%LIBDE_BUILD%\libde265\de265-version.h" "%ROOT%\extras\third_party\libheif\libde265\libde265\"
if errorlevel 1 exit /b 1

set "HEIF_BUILD=%OUT%\libheif"
if exist "%HEIF_BUILD%" rmdir /s /q "%HEIF_BUILD%"
cmake.exe -S "%ROOT%\extras\third_party\libheif\libheif" -B "%HEIF_BUILD%" -A ARM64 -T v142 -DCMAKE_SYSTEM_VERSION=%SDK_VERSION% -DCMAKE_POLICY_VERSION_MINIMUM=3.5 -DDAV1D_LIBRARY="%DAV1D_DIST%\lib\dav1d.lib" -DDAV1D_INCLUDE_DIR="%DAV1D_DIST%\include" -DLIBDE265_LIBRARY="%LIBDE_BUILD%\libde265\Release\de265.lib" -DLIBDE265_INCLUDE_DIR="%ROOT%\extras\third_party\libheif\libde265"
if errorlevel 1 exit /b 1
cmake.exe --build "%HEIF_BUILD%" --config Release --target heif
if errorlevel 1 exit /b 1
copy /y "%HEIF_BUILD%\libheif\Release\heif.dll" "%ROOT%\src\JPEGView\libheif\binarm64\"
if errorlevel 1 exit /b 1
copy /y "%HEIF_BUILD%\libheif\Release\heif.lib" "%ROOT%\src\JPEGView\libheif\libarm64\"
exit /b %errorlevel%

:app
set "ATL_ROOT="
for /f "delims=" %%D in ('dir /b /ad /o:n "%VS_ROOT%\VC\Tools\MSVC"') do (
	if exist "%VS_ROOT%\VC\Tools\MSVC\%%D\atlmfc\lib\arm64\atls.lib" set "ATL_ROOT=%VS_ROOT%\VC\Tools\MSVC\%%D\atlmfc"
)
if not defined ATL_ROOT (
	echo ARM64 atls.lib was not found under %VS_ROOT%.
	exit /b 1
)

set "INCLUDE=%ATL_ROOT%\include;%INCLUDE%"
set "LIB=%ATL_ROOT%\lib\arm64;%LIB%"
set "CL=/I"%ATL_ROOT%\include" %CL%"
set "LINK=/LIBPATH:"%ATL_ROOT%\lib\arm64" %LINK%"

pushd "%ROOT%"
msbuild.exe /nologo /m /t:JPEGView /p:Platform=ARM64 /p:Configuration=Release src\JPEGView.sln /v:minimal
set "BUILD_EXIT=%errorlevel%"
popd
exit /b %BUILD_EXIT%
