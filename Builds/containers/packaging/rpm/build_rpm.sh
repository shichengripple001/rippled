#!/usr/bin/env bash
set -ex

if [ $GITHUB_ACTIONS ];then
    cd ..
else
    cd /opt/rippled_bld/pkg
fi

cp -fpu rippled/Builds/containers/packaging/rpm/rippled.spec .
cp -fpu rippled/Builds/containers/shared/update_sources.sh .
source update_sources.sh

# Build the rpm

IFS='-' read -r RIPPLED_RPM_VERSION RELEASE <<< "$RIPPLED_VERSION"
export RIPPLED_RPM_VERSION

RPM_RELEASE=${RPM_RELEASE-1}

# post-release version
if [ "hf" = "$(echo "$RELEASE" | cut -c -2)" ]; then
    RPM_RELEASE="${RPM_RELEASE}.${RELEASE}"
# pre-release version (-b or -rc)
elif [[ $RELEASE ]]; then
    RPM_RELEASE="0.${RPM_RELEASE}.${RELEASE}"
fi

export RPM_RELEASE

if [[ $RPM_PATCH ]]; then
    RPM_PATCH=".${RPM_PATCH}"
    export RPM_PATCH
fi

git config --global --add safe.directory /__w/rippled/rippled
if [ -z $GITHUB_ACTIONS ];then
    cd /opt/rippled_bld/pkg/rippled
fi

if [[ -n $(git status --porcelain) ]]; then
   git status
   error "Unstaged changes in this repo - please commit first"
fi
# TODO include validator-keys sources
if [ -z $GITHUB_ACTIONS ];then
    git archive --format tar.gz --prefix rippled/ -o ../rpmbuild/SOURCES/rippled.tar.gz HEAD
fi
cd ..
if [ $GITHUB_ACTIONS ];then
    mkdir -p rpmbuild/SOURCES/
    tar czvf rpmbuild/SOURCES/rippled.tar.gz rippled
fi



source /opt/rh/devtoolset-8/enable

rpmbuild --define "_topdir ${PWD}/rpmbuild" -ba rippled.spec
rc=$?; if [[ $rc != 0 ]]; then
    error "error building rpm"
fi

# Make a tar of the rpm and source rpm
RPM_VERSION_RELEASE=$(rpm -qp --qf='%{NAME}-%{VERSION}-%{RELEASE}' ./rpmbuild/RPMS/x86_64/rippled-[0-9]*.rpm)
tar_file=$RPM_VERSION_RELEASE.tar.gz

cp ./rpmbuild/RPMS/x86_64/* ${PKG_OUTDIR}
cp ./rpmbuild/SRPMS/* ${PKG_OUTDIR}

RPM_MD5SUM=$(rpm -q --queryformat '%{SIGMD5}\n' -p ./rpmbuild/RPMS/x86_64/rippled-[0-9]*.rpm 2>/dev/null)
DBG_MD5SUM=$(rpm -q --queryformat '%{SIGMD5}\n' -p ./rpmbuild/RPMS/x86_64/rippled-debuginfo*.rpm 2>/dev/null)
DEV_MD5SUM=$(rpm -q --queryformat '%{SIGMD5}\n' -p ./rpmbuild/RPMS/x86_64/rippled-devel*.rpm 2>/dev/null)
REP_MD5SUM=$(rpm -q --queryformat '%{SIGMD5}\n' -p ./rpmbuild/RPMS/x86_64/rippled-reporting*.rpm 2>/dev/null)
SRC_MD5SUM=$(rpm -q --queryformat '%{SIGMD5}\n' -p ./rpmbuild/SRPMS/*.rpm 2>/dev/null)

RPM_SHA256="$(sha256sum ./rpmbuild/RPMS/x86_64/rippled-[0-9]*.rpm | awk '{ print $1}')"
DBG_SHA256="$(sha256sum ./rpmbuild/RPMS/x86_64/rippled-debuginfo*.rpm | awk '{ print $1}')"
REP_SHA256="$(sha256sum ./rpmbuild/RPMS/x86_64/rippled-reporting*.rpm | awk '{ print $1}')"
DEV_SHA256="$(sha256sum ./rpmbuild/RPMS/x86_64/rippled-devel*.rpm | awk '{ print $1}')"
SRC_SHA256="$(sha256sum ./rpmbuild/SRPMS/*.rpm | awk '{ print $1}')"

echo "rpm_md5sum=$RPM_MD5SUM" >  ${PKG_OUTDIR}/build_vars
echo "rep_md5sum=$REP_MD5SUM" >> ${PKG_OUTDIR}/build_vars
echo "dbg_md5sum=$DBG_MD5SUM" >> ${PKG_OUTDIR}/build_vars
echo "dev_md5sum=$DEV_MD5SUM" >> ${PKG_OUTDIR}/build_vars
echo "src_md5sum=$SRC_MD5SUM" >> ${PKG_OUTDIR}/build_vars
echo "rpm_sha256=$RPM_SHA256" >> ${PKG_OUTDIR}/build_vars
echo "rep_sha256=$REP_SHA256" >> ${PKG_OUTDIR}/build_vars
echo "dbg_sha256=$DBG_SHA256" >> ${PKG_OUTDIR}/build_vars
echo "dev_sha256=$DEV_SHA256" >> ${PKG_OUTDIR}/build_vars
echo "src_sha256=$SRC_SHA256" >> ${PKG_OUTDIR}/build_vars
echo "rippled_version=$RIPPLED_VERSION" >> ${PKG_OUTDIR}/build_vars
echo "rpm_version=$RIPPLED_RPM_VERSION" >> ${PKG_OUTDIR}/build_vars
echo "rpm_file_name=$tar_file" >> ${PKG_OUTDIR}/build_vars
echo "rpm_version_release=$RPM_VERSION_RELEASE" >> ${PKG_OUTDIR}/build_vars
