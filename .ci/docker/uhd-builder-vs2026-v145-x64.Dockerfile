# Docker build context must be uhd/uhddev root

# please follow docker best practices
# https://docs.docker.com/engine/userguide/eng-image/dockerfile_best-practices/

# Defaults for variables used in FROM statement
ARG WIN_BASE_TAG=ltsc2025

FROM mcr.microsoft.com/windows/servercore:${WIN_BASE_TAG}
LABEL maintainer="Ettus Research"

# Minimum required argument
ARG VS_BUILD_TOOLS_URL
# Optional arguments for customization
ARG PYTHON_VERSION=3.10.11
ARG VCPKG_MANIFEST_FILE=vcpkg-vs2026.json
ARG PIP_INDEX_HOST=""
ARG PIP_INDEX_URL=""
ENV VCPKG_DISABLE_METRICS=1
# Optional argument for vcpkg binary cache directory
ARG VCPKG_BINARY_CACHE_DIR="C:\vcpkg-cache"
ENV VCPKG_BINARY_SOURCES=clear;files,${VCPKG_BINARY_CACHE_DIR},readwrite

# Enable long file paths (>260 characters)
RUN reg add HKLM\SYSTEM\CurrentControlSet\Control\FileSystem /v LongPathsEnabled /t REG_DWORD /d 1 /f

# Install vs build tools
COPY .ci/docker/scripts/install-vs-buildtools.ps1 C:/Temp/install-vs-buildtools.ps1
RUN powershell -NoProfile -ExecutionPolicy Bypass -Command \
    "& 'C:\Temp\install-vs-buildtools.ps1' \
    -Url '%VS_BUILD_TOOLS_URL%' \
    -InstallerArgs '--quiet','--wait','--norestart','--nocache', \
        '--add','Microsoft.VisualStudio.Workload.VCTools', \
        '--includeRecommended'"

RUN setx chocolateyVersion 2.5.1 /m
RUN @"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" \
    -NoProfile -InputFormat None -ExecutionPolicy Bypass \
    -Command "[System.Net.ServicePointManager]::SecurityProtocol = 3072; \
    iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))" && \
    SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin" && \
    choco config set webRequestTimeoutSeconds 600
COPY .ci/docker/scripts/install-choco-package.ps1 C:/Temp/install-choco-package.ps1
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:\Temp\install-choco-package.ps1 \
        -PackageName doxygen.install -Version 1.9.8 && \
    powershell -NoProfile -ExecutionPolicy Bypass -File C:\Temp\install-choco-package.ps1 \
        -PackageName cmake.install -Version 4.2.1 -InstallArgs ADD_CMAKE_TO_PATH=System && \
    powershell -NoProfile -ExecutionPolicy Bypass -File C:\Temp\install-choco-package.ps1 \
        -PackageName git && \
    powershell -NoProfile -ExecutionPolicy Bypass -File C:\Temp\install-choco-package.ps1 \
        -PackageName NSIS -Version 3.11.0 && \
    powershell -NoProfile -ExecutionPolicy Bypass -File C:\Temp\install-choco-package.ps1 \
        -PackageName vim && \
    powershell -NoProfile -ExecutionPolicy Bypass -File C:\Temp\install-choco-package.ps1 \
        -PackageName python3 -Version %PYTHON_VERSION%

# Optionally use cached index.
RUN if defined PIP_INDEX_URL ( \
    pip config --global set global.index-url %PIP_INDEX_URL% && \
    pip config --global set global.trusted-host %PIP_INDEX_HOST% \
    )

COPY host/python/requirements.txt C:/Temp/requirements.txt
RUN pip config list && \
    python -m pip install --upgrade pip && \
    python -m pip install -r C:/Temp/requirements.txt

RUN setx VCPKG_INSTALL_DIR "c:\\vcpkg" /m
RUN git clone https://github.com/microsoft/vcpkg %VCPKG_INSTALL_DIR% && \
    cd %VCPKG_INSTALL_DIR% && \
    bootstrap-vcpkg.bat
# Add custom UHD vcpkg triplet
COPY host/cmake/vcpkg/* c:/vcpkg/triplets/
# Define triplet to be used by this container
RUN setx VCPKG_TARGET_TRIPLET "uhd-x64-windows-static-md" /m
RUN echo set(VCPKG_BUILD_TYPE release)>>"%VCPKG_INSTALL_DIR%\triplets\%VCPKG_TARGET_TRIPLET%.cmake"
RUN type "%VCPKG_INSTALL_DIR%\triplets\%VCPKG_TARGET_TRIPLET%.cmake"
# Copy vcpkg cache from mapped folder to 
RUN echo Current path %cd%
COPY .cache/vcpkg ${VCPKG_BINARY_CACHE_DIR}

RUN powershell -NoProfile -ExecutionPolicy Bypass -Command \
    "New-Item -ItemType Directory -Path 'c:\uhd-vcpkg' -Force | Out-Null"
COPY .ci/docker/vcpkg/${VCPKG_MANIFEST_FILE} c:/uhd-vcpkg/vcpkg.json
COPY .ci/docker/scripts/install-vcpkg-triplet.ps1 C:/Temp/install-vcpkg-triplet.ps1
RUN powershell -NoProfile -ExecutionPolicy Bypass -File C:\Temp\install-vcpkg-triplet.ps1 \
    -ManifestDir C:\uhd-vcpkg \
    -Triplet %VCPKG_TARGET_TRIPLET% \
    -VcpkgRoot %VCPKG_INSTALL_DIR%
