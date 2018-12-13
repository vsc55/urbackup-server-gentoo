# Copyright 1999-2006 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# $Header: $

EAPI=6
inherit eutils user systemd

DESCRIPTION="Servidor UrBackup, permite hacer copias de sguridad de documentos de todos los puestos de la red."
HOMEPAGE="http://www.urbackup.org"
SRC_URI="https://hndl.urbackup.org/Server/${PV}/${P}.tar.gz"
S="${WORKDIR}/${P}"

SLOT="0"
LICENSE="AGPL-3"
KEYWORDS="x86 amd64"
IUSE="-systemd crypt hardened fuse mail zlib"


RDEPEND="
	crypt? ( dev-libs/crypto++ )
	dev-db/sqlite
	fuse? ( sys-fs/fuse )
	mail? ( >=net-misc/curl-7.2 )
	zlib? ( sys-libs/zlib )"
DEPEND="${RDEPEND}"


PATCHES=(
	"${FILESDIR}/urbackup-server-2.3.7-autoupdate-code.patch"
	"${FILESDIR}/urbackup-server-2.3.7-autoupdate-config.patch"
	"${FILESDIR}/urbackup-server-2.3.7-autoupdate-ui.patch"
	"${FILESDIR}/urbackup-server-2.3.7-autoupdate-datafiles-gcc-fortify.patch"
)


INIT_SCRIPT_OLD="${ROOT}/etc/init.d/urbackup_srv"
INIT_SCRIPT="${ROOT}/etc/init.d/urbackupsrv"


pkg_setup() {
	enewgroup urbackup
	enewuser urbackup -1 /bin/bash "${EPREFIX}"/var/lib/urbackup urbackup
}

src_configure() {
	cd "${S}"
	econf \
	$(use_with crypt crypto) \
	$(use_enable hardened fortify) \
	$(use_with fuse mountvhd) \
	$(use_with mail) \
	$(use_with zlib) \
	--enable-packaging
}

#src_compile() {
#	cd "${S}"
#	emake DESTDIR="${D}"
#}

src_install() {
	cd "${S}"

	dodir "${EPREFIX}"/usr/share/man/man1
	emake DESTDIR="${D}" install
	insinto "${EPREFIX}"/etc/logrotate.d
	if use systemd; then
		newins logrotate_urbackupsrv urbackupsrv
	else
		newins "${FILESDIR}"/urbackupsrv.logrotate urbackupsrv
	fi
	newconfd "${FILESDIR}"/urbackupsrv.conf_v3 urbackupsrv
	doinitd "${FILESDIR}"/urbackupsrv.init_v3 urbackupsrv
	
	if use systemd; then
		systemd_dounit ${FILESDIR}/urbackup-server.service_v2 urbackup-server.service
		#systemctl enable urbackup-server.service
	fi
	
	fowners -R urbackup:urbackup "${EPREFIX}/var/lib/urbackup"
	fowners -R urbackup:urbackup "${EPREFIX}/usr/share/urbackup/www"	
}

pkg_preinst() {
	# Mata el proceso antes de copiar la nueva version de programa al HD.
	einfo "Stopping running instances of UrBackup Server"
	if [ -e "${INIT_SCRIPT_OLD}" ]; then
		${INIT_SCRIPT_OLD} stop
	fi
	if [ -e "${INIT_SCRIPT}" ]; then
		${INIT_SCRIPT} stop
	fi
}

pkg_prerm() {
	# Mata el proceso antes de desintalar.
	einfo "Stopping running instances of UrBackup Server"
	if [ -e "${INIT_SCRIPT_OLD}" ]; then
		${INIT_SCRIPT_OLD} stop
	fi
	if [ -e "${INIT_SCRIPT}" ]; then
		${INIT_SCRIPT} stop
	fi
}

pkg_postinst() {
	einfo ""
	elog "Browse to http://localhost:55414 and setup an admin user and the backup storage path."
	elog ""
	elog "Setup auto start daemon:"
	elog "# rc-update add urbackupsrv default"
	elog ""
	elog "Start service:"
	elog "# /etc/init.d/urbackupsrv start"
	einfo ""
	#If your distribution is not Debian or Debian based you have to either build your own init script or just put /usr/local/sbin/urbackupsrv run -d into /etc/rc.local.
}