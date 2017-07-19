#!/bin/bash

set -ex

REVSION=$(git rev-list --count HEAD)
HTTP2REV=$(cd ${GOPATH}/src/github.com/phuslu/net/http2; git log --oneline -1 --format="%h")
LDFLAGS="-s -w -X main.version=r${REVSION} -X main.http2rev=${HTTP2REV}"

GOOS=${GOOS:-$(go env GOOS)}
GOARCH=${GOARCH:-$(go env GOARCH)}
CGO_ENABLED=${CGO_ENABLED:-$(go env CGO_ENABLED)}

REPO=$(git rev-parse --show-toplevel)
PACKAGE=$(basename ${REPO})
if [ "${CGO_ENABLED}" = "0" ]; then
    BUILDROOT=${REPO}/build/${GOOS}_${GOARCH}
else
    BUILDROOT=${REPO}/build/${GOOS}_${GOARCH}_cgo
fi
STAGEDIR=${BUILDROOT}/stage
OBJECTDIR=${BUILDROOT}/obj
DISTDIR=${BUILDROOT}/dist

if [ "${GOOS}" == "windows" ]; then
    GOPROXY_EXE="${PACKAGE}.exe"
    GOPROXY_STAGEDIR="${STAGEDIR}"
    GOPROXY_DISTCMD="7za a -y -mx=9 -m0=lzma -mfb=128 -md=64m -ms=on"
    GOPROXY_DISTEXT=".7z"
elif [ "${GOOS}" == "darwin" ]; then
    GOPROXY_EXE="${PACKAGE}"
    GOPROXY_STAGEDIR="${STAGEDIR}"
    GOPROXY_DISTCMD="env BZIP=-9 tar cvjpf"
    GOPROXY_DISTEXT=".tar.bz2"
elif [ "${GOARCH:0:3}" == "arm" ]; then
    GOPROXY_EXE="${PACKAGE}"
    GOPROXY_STAGEDIR="${STAGEDIR}"
    GOPROXY_DISTCMD="env BZIP=-9 tar cvjpf"
    GOPROXY_DISTEXT=".tar.bz2"
elif [ "${GOARCH:0:4}" == "mips" ]; then
    GOPROXY_EXE="${PACKAGE}"
    GOPROXY_STAGEDIR="${STAGEDIR}"
    GOPROXY_DISTCMD="env GZIP=-9 tar cvzpf"
    GOPROXY_DISTEXT=".tar.gz"
else
    GOPROXY_EXE="${PACKAGE}"
    GOPROXY_STAGEDIR="${STAGEDIR}/${PACKAGE}"
    GOPROXY_DISTCMD="env XZ_OPT=-9 tar cvJpf"
    GOPROXY_DISTEXT=".tar.xz"
fi

GOPROXY_DIST=${DISTDIR}/${PACKAGE}_${GOOS}_${GOARCH}-r${REVSION}${GOPROXY_DISTEXT}
if [ "${CGO_ENABLED}" = "1" ]; then
    GOPROXY_DIST=${DISTDIR}/${PACKAGE}_${GOOS}_${GOARCH}_cgo-r${REVSION}${GOPROXY_DISTEXT}
fi

GOPROXY_GUI_EXE=${REPO}/assets/taskbar/${GOARCH}/goproxy-gui.exe
if [ ! -f "${GOPROXY_GUI_EXE}" ]; then
    GOPROXY_GUI_EXE=${REPO}/assets/packaging/goproxy-gui.exe
fi

OBJECTS=${OBJECTDIR}/${GOPROXY_EXE}

SOURCES="${REPO}/README.md \
        ${REPO}/assets/packaging/gae.user.json.example \
        ${REPO}/httpproxy/filters/auth/auth.json \
        ${REPO}/httpproxy/filters/autoproxy/17monipdb.dat \
        ${REPO}/httpproxy/filters/autoproxy/autoproxy.json \
        ${REPO}/httpproxy/filters/autoproxy/gfwlist.txt \
        ${REPO}/httpproxy/filters/autoproxy/ip.html \
        ${REPO}/httpproxy/filters/autorange/autorange.json \
        ${REPO}/httpproxy/filters/direct/direct.json \
        ${REPO}/httpproxy/filters/gae/gae.json \
        ${REPO}/httpproxy/filters/php/php.json \
        ${REPO}/httpproxy/filters/rewrite/rewrite.json \
        ${REPO}/httpproxy/filters/stripssl/stripssl.json \
        ${REPO}/httpproxy/httpproxy.json"

if [ "${GOOS}" = "windows" ]; then
    SOURCES="${SOURCES} \
             ${GOPROXY_GUI_EXE} \
             ${REPO}/assets/packaging/addto-startup.vbs \
             ${REPO}/assets/packaging/get-latest-goproxy.cmd"
elif [ "${GOOS}_${GOARCH}_${CGO_ENABLED}" = "linux_arm_0" ]; then
    SOURCES="${SOURCES} \
             ${REPO}/assets/packaging/goproxy.sh \
             ${REPO}/assets/packaging/get-latest-goproxy.sh"
    GOARM=${GORAM:-5}
elif [ "${GOOS}_${GOARCH}_${CGO_ENABLED}" = "linux_arm_1" ]; then
    SOURCES="${SOURCES} \
             ${REPO}/assets/packaging/goproxy.sh \
             ${REPO}/assets/packaging/get-latest-goproxy.sh"
    CC=${ARM_CC:-arm-linux-gnueabihf-gcc}
    GOARM=${GORAM:-5}
elif [ "${GOOS}" = "darwin" ]; then
    SOURCES="${SOURCES} \
             ${REPO}/assets/packaging/goproxy-macos.command \
             ${REPO}/assets/packaging/get-latest-goproxy.sh"
else
    SOURCES="${SOURCES} \
             ${REPO}/assets/packaging/get-latest-goproxy.sh \
             ${REPO}/assets/packaging/goproxy-gtk.desktop \
             ${REPO}/assets/packaging/goproxy-gtk.png \
             ${REPO}/assets/packaging/goproxy-gtk.py \
             ${REPO}/assets/packaging/goproxy.sh"
fi

build () {
    mkdir -p ${OBJECTDIR}
    env GOOS=${GOOS} \
        GOARCH=${GOARCH} \
        GOARM=${GOARM} \
        CGO_ENABLED=${CGO_ENABLED} \
        CC=${CC} \
    go build -v -ldflags="${LDFLAGS}" -o ${OBJECTDIR}/${GOPROXY_EXE} .
}

dist () {
    mkdir -p ${DISTDIR} ${STAGEDIR} ${GOPROXY_STAGEDIR}
    cp ${OBJECTS} ${SOURCES} ${GOPROXY_STAGEDIR}

    pushd ${STAGEDIR}
    ${GOPROXY_DISTCMD} ${GOPROXY_DIST} *
    popd
}

check () {
    GOPROXY_WAIT_SECONDS=0 ${GOPROXY_STAGEDIR}/${GOPROXY_EXE}
}

clean () {
    rm -rf ${BUILDROOT}
}

case $1 in
    build)
        build
        ;;
    dist)
        dist
        ;;
    check)
        check
        ;;
    clean)
        clean
        ;;
    *)
        build
        dist
        ;;
esac
