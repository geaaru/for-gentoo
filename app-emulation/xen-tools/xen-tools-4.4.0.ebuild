# Copyright 1999-2014 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: /var/cvsroot/gentoo-x86/app-emulation/xen-tools/xen-tools-4.4.0.ebuild,v 1.2 2014/03/24 05:07:27 idella4 Exp $

EAPI=5

MY_PV=${PV/_/-}

PYTHON_COMPAT=( python2_7 )
PYTHON_REQ_USE='xml,threads'

if [[ $PV == *9999 ]]; then
	KEYWORDS=""
	REPO="xen-unstable.hg"
	EHG_REPO_URI="http://xenbits.xensource.com/${REPO}"
	S="${WORKDIR}/${REPO}"
	live_eclass="mercurial"
else
	KEYWORDS="~amd64 ~arm -x86"
	UPSTREAM_VER=
	GENTOO_VER=

	[[ -n ${UPSTREAM_VER} ]] && \
		UPSTRAM_PATCHSET_URI="http://dev.gentoo.org/~dlan/distfiles/${P/-tools/}-upstream-patches-${UPSTREAM_VER}.tar.xz"
	[[ -n ${GENTOO_VER} ]] && \
		GENTOO_PATCHSET_URI="http://dev.gentoo.org/~dlan/distfiles/${P/-tools/}-gentoo-patches-${GENTOO_VER}.tar.xz"

	SRC_URI="http://bits.xensource.com/oss-xen/release/${MY_PV}/xen-${MY_PV}.tar.gz
	${UPSTRAM_PATCHSET_URI}
	${GENTOO_PATCHSET_URI}"
	S="${WORKDIR}/xen-${MY_PV}"
fi

inherit bash-completion-r1 eutils flag-o-matic multilib python-single-r1 toolchain-funcs udev ${live_eclass}

DESCRIPTION="Xend daemon and tools"
HOMEPAGE="http://xen.org/"
DOCS=( README docs/README.xen-bugtool )

LICENSE="GPL-2"
SLOT="0"
# Inclusion of IUSE ocaml on stabalizing requires maintainer of ocaml to (get off his hands and) make
# >=dev-lang/ocaml-4 stable
# Masked in profiles/eapi-5-files instead
IUSE="api custom-cflags debug doc flask hvm qemu ocaml +pam python pygrub screen static-libs"

REQUIRED_USE="hvm? ( qemu )
	${PYTHON_REQUIRED_USE}
	pygrub? ( python )"

COMMON_DEPEND="
	dev-libs/lzo:2
	dev-libs/glib:2
	dev-libs/yajl
	dev-libs/libaio
	dev-libs/libgcrypt:0
	sys-libs/zlib
"

DEPEND="${COMMON_DEPEND}
	dev-python/lxml[${PYTHON_USEDEP}]
	pam? ( dev-python/pypam[${PYTHON_USEDEP}] )
	hvm? ( media-libs/libsdl )
	${PYTHON_DEPS}
	api? ( dev-libs/libxml2
		net-misc/curl )
	pygrub? ( ${PYTHON_DEPS//${PYTHON_REQ_USE}/ncurses} )
	arm? ( >=sys-apps/dtc-1.4.0 )
	!arm? ( sys-devel/bin86
		sys-firmware/ipxe
		sys-firmware/seabios
		sys-devel/dev86
		sys-power/iasl )
	dev-lang/perl
	app-misc/pax-utils
	dev-python/markdown
	doc? (
		app-doc/doxygen
		dev-tex/latex2html[png,gif]
		media-gfx/graphviz
		dev-tex/xcolor
		media-gfx/transfig
		dev-texlive/texlive-latexextra
		virtual/latex-base
		dev-tex/latexmk
		dev-texlive/texlive-latex
		dev-texlive/texlive-pictures
		dev-texlive/texlive-latexrecommended
	)
	hvm? ( x11-proto/xproto
		!net-libs/libiscsi )
	qemu? ( x11-libs/pixman )
	ocaml? ( dev-ml/findlib
		>=dev-lang/ocaml-4 )"

RDEPEND="${COMMON_DEPEND}
	sys-apps/iproute2
	net-misc/bridge-utils
	screen? (
		app-misc/screen
		app-admin/logrotate
	)
	virtual/udev"

# hvmloader is used to bootstrap a fully virtualized kernel
# Approved by QA team in bug #144032
QA_WX_LOAD="usr/lib/xen/boot/hvmloader"

RESTRICT="test"

pkg_setup() {
	python-single-r1_pkg_setup
	export "CONFIG_LOMOUNT=y"

	if has_version dev-libs/libgcrypt:0; then
		export "CONFIG_GCRYPT=y"
	fi

	if use qemu; then
		export "CONFIG_IOEMU=y"
	else
		export "CONFIG_IOEMU=n"
	fi

	if ! use x86 && ! has x86 $(get_all_abis) && use hvm; then
		eerror "HVM (VT-x and AMD-v) cannot be built on this system. An x86 or"
		eerror "an amd64 multilib profile is required. Remove the hvm use flag"
		eerror "to build xen-tools on your current profile."
		die "USE=hvm is unsupported on this system."
	fi

	if [[ -z ${XEN_TARGET_ARCH} ]] ; then
		if use x86 && use amd64; then
			die "Confusion! Both x86 and amd64 are set in your use flags!"
		elif use x86; then
			export XEN_TARGET_ARCH="x86_32"
		elif use amd64 ; then
			export XEN_TARGET_ARCH="x86_64"
		elif use arm; then
			export XEN_TARGET_ARCH="arm32"
		else
			die "Unsupported architecture!"
		fi
	fi
	#bug 472438
	export BASH_COMPLETION_DIR=/usr/share/bash-completion
}

src_prepare() {
	# Upstream's patchset
	if [[ -n ${UPSTREAM_VER} ]]; then
		EPATCH_SUFFIX="patch" \
		EPATCH_FORCE="yes" \
			epatch "${WORKDIR}"/patches-upstream
	fi

	# Gentoo's patchset
	if [[ -n ${GENTOO_VER} ]]; then
		EPATCH_SUFFIX="patch" \
		EPATCH_FORCE="yes" \
			epatch "${WORKDIR}"/patches-gentoo
	fi

	# Fix texi2html build error with new texi2html, qemu.doc.html
	epatch "${FILESDIR}"/${PN}-4-docfix.patch

	# Fix network broadcast on bridged networks
	epatch "${FILESDIR}/${PN}-3.4.0-network-bridge-broadcast.patch"

	# Bug 496708
	epatch "${FILESDIR}"/${PN}-4-unbundle-ipxe.patch

	# Fix bridge by idella4, bug #362575
	epatch "${FILESDIR}/${PN}-4.1.1-bridge.patch"

	# Prevent double stripping of files at install
	epatch "${FILESDIR}"/${PN/-tools/}-4.4-nostrip.patch

	# fix jobserver in Makefile
	epatch "${FILESDIR}"/${PN/-tools/}-4.3-jserver.patch

	# Set dom0-min-mem to kb; Bug #472982
	epatch "${FILESDIR}"/${PN/-tools/}-4.2-configsxp.patch

	# Bug 477676
	epatch "${FILESDIR}"/${PN}-4.3-ar-cc.patch

	# Bug 379537
	epatch "${FILESDIR}"/fix-gold-ld.patch

	# Prevent file collision with qemu package Bug 478064
	epatch "${FILESDIR}"/xen-4.4-qemu-bridge.patch
	mv tools/qemu-xen/qemu-bridge-helper.c tools/qemu-xen/xen-bridge-helper.c || die

	epatch "${FILESDIR}"/${PN}-4.4-api-fix.patch

	use api   || sed -e "/SUBDIRS-\$(LIBXENAPI_BINDINGS) += libxen/d" -i tools/Makefile || die
	sed -e 's:$(MAKE) PYTHON=$(PYTHON) subdirs-$@:LC_ALL=C "$(MAKE)" PYTHON=$(PYTHON) subdirs-$@:' \
		 -i tools/firmware/Makefile || die

	# Drop .config, fixes to gcc-4.6
	sed -e '/-include $(XEN_ROOT)\/.config/d' -i Config.mk || die "Couldn't	drop"

	# if the user *really* wants to use their own custom-cflags, let them
	if use custom-cflags; then
		einfo "User wants their own CFLAGS - removing defaults"

		# try and remove all the default cflags
		find "${S}" \( -name Makefile -o -name Rules.mk -o -name Config.mk \) \
			-exec sed \
				-e 's/CFLAGS\(.*\)=\(.*\)-O3\(.*\)/CFLAGS\1=\2\3/' \
				-e 's/CFLAGS\(.*\)=\(.*\)-march=i686\(.*\)/CFLAGS\1=\2\3/' \
				-e 's/CFLAGS\(.*\)=\(.*\)-fomit-frame-pointer\(.*\)/CFLAGS\1=\2\3/' \
				-e 's/CFLAGS\(.*\)=\(.*\)-g3*\s\(.*\)/CFLAGS\1=\2 \3/' \
				-e 's/CFLAGS\(.*\)=\(.*\)-O2\(.*\)/CFLAGS\1=\2\3/' \
				-i {} + || die "failed to re-set custom-cflags"
	fi

	if ! use pygrub; then
		sed -e '/^SUBDIRS-y += pygrub/d' -i tools/Makefile || die
	fi

	if ! use python; then
		sed -e '/^SUBDIRS-y += python$/d' -i tools/Makefile || die
	fi

	# Disable hvm support on systems that don't support x86_32 binaries.
	if ! use hvm; then
		sed -e '/SUBDIRS-$(CONFIG_X86) += firmware/d' -i tools/Makefile || die
	fi

	# Don't bother with qemu, only needed for fully virtualised guests
	if ! use qemu; then
		sed -e "s:install-tools\: tools/qemu-xen-traditional-dir:install-tools\: :g" -i Makefile || die
	fi

	# Bug 472438
	sed -e 's:^BASH_COMPLETION_DIR ?= $(CONFIG_DIR)/bash_completion.d:BASH_COMPLETION_DIR ?= $(SHARE_DIR)/bash-completion:' \
		-i Config.mk || die

	# xencommons, Bug #492332, sed lighter weight than patching
	sed -e 's:\$QEMU_XEN -xen-domid:test -e "\$QEMU_XEN" \&\& &:' \
		-i tools/hotplug/Linux/init.d/xencommons || die

	# respect multilib, usr/lib/libcacard.so.0.0.0
	sed -e "/^libdir=/s/\/lib/\/$(get_libdir)/" \
		-i tools/qemu-xen/configure || die

	# fix QA warning, create /var/run/, /var/lock dynamically
	sed -i -e "/\$(INSTALL_DIR) \$(DESTDIR)\$(XEN_RUN_DIR)/d" \
		tools/libxl/Makefile || die

	sed -i -e "/\/var\/run\//d" \
		tools/xenstore/Makefile \
		tools/pygrub/Makefile || die

	sed -i -e "/\/var\/lock\/subsys/d" \
		tools/Makefile || die

	epatch_user
}

src_configure() {
	local myconf="--prefix=/usr \
		--libdir=/usr/$(get_libdir) \
		--disable-werror \
		--with-system-seabios=/usr/share/seabios/bios.bin \
		--disable-xen \
		--enable-tools \
		--enable-docs \
		$(use_enable pam) \
		$(use_enable api xenapi) \
		$(use_enable ocaml ocamltools) \
		"
	econf ${myconf}
}

src_compile() {
	export VARTEXFONTS="${T}/fonts"
	local myopt
	use debug && myopt="${myopt} debug=y"

	use custom-cflags || unset CFLAGS
	if test-flag-CC -fno-strict-overflow; then
		append-flags -fno-strict-overflow
	fi

	unset LDFLAGS
	unset CFLAGS
	emake V=1 CC="$(tc-getCC)" LD="$(tc-getLD)" AR="$(tc-getAR)" RANLIB="$(tc-getRANLIB)" -C tools ${myopt}

	use doc && emake -C docs txt html
	emake -C docs man-pages
}

src_install() {
	# Override auto-detection in the build system, bug #382573
	export INITD_DIR=/tmp/init.d
	export CONFIG_LEAF_DIR=../tmp/default

	# Let the build system compile installed Python modules.
	local PYTHONDONTWRITEBYTECODE
	export PYTHONDONTWRITEBYTECODE

	emake DESTDIR="${ED}" DOCDIR="/usr/share/doc/${PF}" \
		XEN_PYTHON_NATIVE_INSTALL=y install-tools

	# Fix the remaining Python shebangs.
	python_fix_shebang "${D}"

	# Remove RedHat-specific stuff
	rm -rf "${D}"tmp || die

	# uncomment lines in xl.conf
	sed -e 's:^#autoballoon=1:autoballoon=1:' \
		-e 's:^#lockfile="/var/lock/xl":lockfile="/var/lock/xl":' \
		-e 's:^#vifscript="vif-bridge":vifscript="vif-bridge":' \
		-i tools/examples/xl.conf  || die

	# Reset bash completion dir; Bug 472438
	mv "${D}"bash-completion "${D}"usr/share/ || die

	if use doc; then
		emake DESTDIR="${D}" DOCDIR="/usr/share/doc/${PF}" install-docs

		dohtml -r docs/
		docinto pdf
		dodoc ${DOCS[@]}
		[ -d "${D}"/usr/share/doc/xen ] && mv "${D}"/usr/share/doc/xen/* "${D}"/usr/share/doc/${PF}/html
	fi

	rm -rf "${D}"/usr/share/doc/xen/
	doman docs/man?/*

	newconfd "${FILESDIR}"/xendomains.confd xendomains
	newconfd "${FILESDIR}"/xenstored.confd xenstored
	newconfd "${FILESDIR}"/xenconsoled.confd xenconsoled
	newinitd "${FILESDIR}"/xendomains.initd-r2 xendomains
	newinitd "${FILESDIR}"/xenstored.initd xenstored
	newinitd "${FILESDIR}"/xenconsoled.initd xenconsoled
	newinitd "${FILESDIR}"/xencommons.initd xencommons
	newconfd "${FILESDIR}"/xencommons.confd xencommons
	newinitd "${FILESDIR}"/xenqemudev.initd xenqemudev
	newconfd "${FILESDIR}"/xenqemudev.confd xenqemudev

	if use screen; then
		cat "${FILESDIR}"/xendomains-screen.confd >> "${D}"/etc/conf.d/xendomains || die
		cp "${FILESDIR}"/xen-consoles.logrotate "${D}"/etc/xen/ || die
		keepdir /var/log/xen-consoles
	fi

	# Move files built with use qemu, Bug #477884
	if [[ "${ARCH}" == 'amd64' ]] && use qemu; then
		mkdir -p "${D}"usr/$(get_libdir)/xen/bin || die
		mv "${D}"usr/lib/xen/bin/* "${D}"usr/$(get_libdir)/xen/bin/ || die
	fi

	# For -static-libs wrt Bug 384355
	if ! use static-libs; then
		rm -f "${D}"usr/$(get_libdir)/*.a "${D}"usr/$(get_libdir)/ocaml/*/*.a
	fi

	# xend expects these to exist
	keepdir /var/lib/xenstored /var/xen/dump /var/lib/xen /var/log/xen

	# for xendomains
	keepdir /etc/xen/auto

	# Temp QA workaround
	dodir "$(udev_get_udevdir)"
	mv "${D}"/etc/udev/* "${D}/$(udev_get_udevdir)"
	rm -rf "${D}"/etc/udev

	# Remove files failing QA AFTER emake installs them, avoiding seeking absent files
	find "${D}" \( -name openbios-sparc32 -o -name openbios-sparc64 \
		-o -name openbios-ppc -o -name palcode-clipper \) -delete || die

	# Fix collisions with qemu-1.6.x
	rm -rf "${D}"/usr/share/man/man*/qemu* "${D}"/usr/share/locale/*/LC_MESSAGES/qemu.mo
}

pkg_postinst() {
	elog "Official Xen Guide and the offical wiki page:"
	elog "https://wiki.gentoo.org/wiki/Xen"
	elog "http://wiki.xen.org/wiki/Main_Page"
	elog ""
	elog "Recommended to utilise the xencommons script to config sytem At boot"
	elog "Add by use of rc-update on completion of the install"

	if [[ "$(scanelf -s __guard -q "${PYTHON}")" ]] ; then
		echo
		ewarn "xend may not work when python is built with stack smashing protection (ssp)."
		ewarn "If 'xm create' fails with '<ProtocolError for /RPC2: -1 >', see bug #141866"
		ewarn "This problem may be resolved as of Xen 3.0.4, if not post in the bug."
	fi

	# TODO: we need to have the current Python slot here.
	if ! has_version "dev-lang/python[ncurses]"; then
		echo
		ewarn "NB: Your dev-lang/python is built without USE=ncurses."
		ewarn "Please rebuild python with USE=ncurses to make use of xenmon.py."
	fi

	if has_version "sys-apps/iproute2[minimal]"; then
		echo
		ewarn "Your sys-apps/iproute2 is built with USE=minimal. Networking"
		ewarn "will not work until you rebuild iproute2 without USE=minimal."
	fi

	if ! use hvm; then
		echo
		elog "HVM (VT-x and AMD-V) support has been disabled. If you need hvm"
		elog "support enable the hvm use flag."
		elog "An x86 or amd64 multilib system is required to build HVM support."
	fi

	if use qemu; then
		elog "The qemu-bridge-helper is renamed to the xen-bridge-helper in the in source"
		elog "build of qemu.  This allows for app-emulation/qemu to be emerged concurrently"
		elog "with the qemu capable xen.  It is up to the user to distinguish between and utilise"
		elog "the qemu-bridge-helper and the xen-bridge-helper.  File bugs of any issues that arise"
	fi

	if grep -qsF XENSV= "${ROOT}/etc/conf.d/xend"; then
		echo
		elog "xensv is broken upstream (Gentoo bug #142011)."
		elog "Please remove '${ROOT%/}/etc/conf.d/xend', as it is no longer needed."
	fi
}