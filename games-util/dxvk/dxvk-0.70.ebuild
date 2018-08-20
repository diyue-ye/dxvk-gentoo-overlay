# Copyright 1999-2018 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6
inherit meson multilib-minimal

DESCRIPTION="A Vulkan-based translation layer for Direct3D 10/11"
HOMEPAGE="https://github.com/doitsujin/dxvk"

if [[ ${PV} == "9999" ]] ; then
        EGIT_REPO_URI="https://github.com/doitsujin/dxvk.git"
        EGIT_BRANCH="master"
        inherit git-r3
        SRC_URI=""
else
        SRC_URI="https://github.com/doitsujin/dxvk/archive/v${PV}.tar.gz -> ${P}.tar.gz"
        KEYWORDS="-* ~amd64 ~x86"
fi

LICENSE="ZLIB"
SLOT="${PV}"
IUSE="+abi_x86_32 +abi_x86_64 tests +utils"

REQUIRED_USE="|| ( abi_x86_32 abi_x86_64 )"

RESTRICT="test"

RDEPEND="
        || (
		>=app-emulation/wine-vanilla-3.14:=[${MULTILIB_USEDEP},vulkan]
		>=app-emulation/wine-staging-3.14:=[${MULTILIB_USEDEP},vulkan]
		>=app-emulation/wine-d3d9-3.14:=[${MULTILIB_USEDEP},vulkan]
		>=app-emulation/wine-any-3.14:=[${MULTILIB_USEDEP},vulkan]
	)
"
DEPEND="${RDEPEND}
	>=sys-devel/gcc-7.3.0
	dev-util/glslang
	utils? (
		app-emulation/winetricks
	)
"

PATCHES=(
	"${FILESDIR}/${P}-fix-32bit-build.patch"
	"${FILESDIR}/${P}-winelib-fix.patch"
	"${FILESDIR}/${P}-option-for-utils.patch"
)

src_prepare() {
	if use utils; then
	        cp "${FILESDIR}/setup.sh" "${T}/dxvk-setup-${PV}"
		cp "${FILESDIR}/setup_dxvk_winelib.verb" "${T}"
		sed -e "s/@verb_location@/${EPREFIX}\/usr\/share\/dxvk-${PV}/" -i ${T}/dxvk-setup-${PV} || die
	fi

	default
}

multilib_src_configure() {
	local emesonargs=(
		--buildtype "release"
		--libdir="$(get_libdir)/dxvk-${PV}"
		$(meson_use tests enable_tests)
		--unity on
	)
	if [[ ${ABI} == amd64 ]]; then
		emesonargs+=(
			--cross-file "$S/build-wine64.txt"
		)
	else
		emesonargs+=(
			--cross-file "$S/build-wine32.txt"
		)
	fi
	meson_src_configure

        if use utils; then
		sed -e "s/@dll_dir_${ABI}@/${EPREFIX}\/usr\/$(get_libdir)\/dxvk-${PV}/" -i ${T}/setup_dxvk_winelib.verb || die
        fi
}

multilib_src_install() {
	meson_src_install
}

multilib_src_install_all() {
    if use utils; then
	# install winetricks verb
	insinto ${EPREFIX}/usr/share/dxvk-${PV}
	doins ${T}/setup_dxvk_winelib.verb

	# create combined setup helper
	exeinto ${EPREFIX}/usr/bin
	doexe ${T}/dxvk-setup-${PV}
    fi

    einstalldocs
}
