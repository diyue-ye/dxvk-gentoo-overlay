# Copyright 1999-2019 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=6

MULTILIB_COMPAT=( abi_x86_{32,64} )

inherit meson multilib-minimal

DESCRIPTION="A Vulkan-based translation layer for Direct3D 9"
HOMEPAGE="https://github.com/Joshua-Ashton/d9vk"

if [[ ${PV} == "9999" ]] ; then
	EGIT_REPO_URI="https://github.com/Joshua-Ashton/d9vk.git"
	EGIT_BRANCH="master"
	inherit git-r3
	SRC_URI=""
else
	SRC_URI="https://github.com/Joshua-Ashton/d9vk/archive/v${PV}.tar.gz -> ${P}.tar.gz"
	KEYWORDS="-* ~amd64"
fi

LICENSE="ZLIB"
SLOT="${PV}"
IUSE="utils"

RESTRICT="test"

RDEPEND="
	|| (
		>=app-emulation/wine-vanilla-3.14:*[${MULTILIB_USEDEP},vulkan]
		>=app-emulation/wine-staging-3.14:*[${MULTILIB_USEDEP},vulkan]
		>=app-emulation/wine-d3d9-3.14:*[${MULTILIB_USEDEP},vulkan]
		>=app-emulation/wine-any-3.14:*[${MULTILIB_USEDEP},vulkan]
	)
	utils? ( app-emulation/winetricks )"
DEPEND="${RDEPEND}
	dev-util/glslang"

PATCHES=(
	"${FILESDIR}/d9vk-d3d9-only.patch"
)

bits() { [[ ${ABI} = amd64 ]] && echo 64 || echo 32; }

dxvk_check_requirements() {
	if [[ ${MERGE_TYPE} != binary ]]; then
		if ! tc-is-gcc || [[ $(gcc-major-version) -lt 7 || $(gcc-major-version) -eq 7 && $(gcc-minor-version) -lt 3 ]]; then
			die "At least gcc 7.3 is required"
		fi
	fi
}

pkg_pretend() {
	dxvk_check_requirements
}

pkg_setup() {
	dxvk_check_requirements
}

src_prepare() {
	if use utils; then
	    cp "${FILESDIR}/setup.sh" "${T}/d9vk-setup-${PV}"
		cp "${FILESDIR}/setup_d9vk_winelib.verb" "${T}"
		sed -e "s/@verb_location@/${EPREFIX}\/usr\/share\/d9vk-${PV}/" -i "${T}/d9vk-setup-${PV}" || die
	fi

	default

	bootstrap_d9vk() {
		local file=build-wine$(bits).txt

		sed -E \
			-e "s#^(c_args.*)#\1 + $(_meson_env_array "${CFLAGS}")#" \
			-e "s#^(cpp_args.*)#\1 + $(_meson_env_array "${CXXFLAGS}")#" \
			-e "s#^(cpp_link_args.*)#\1 + $(_meson_env_array "${LDFLAGS}")#" \
			-i ${file} || die
	}

	multilib_foreach_abi bootstrap_d9vk
}

multilib_src_configure() {
	local emesonargs=(
		--cross-file="${S}/build-wine$(bits).txt"
		--libdir="$(get_libdir)/d9vk-${PV}"
		--bindir="$(get_libdir)/d9vk-${PV}/bin"
		-Denable_tests=false
		--unity=on
	)
	meson_src_configure

	if use utils; then
		sed -e "s/@dll_dir_${ABI}@/${EPREFIX}\/usr\/$(get_libdir)\/d9vk-${PV}/" -i "${T}/setup_d9vk_winelib.verb" || die
	fi
}

multilib_src_install() {
	meson_src_install
}

multilib_src_install_all() {
    if use utils; then
		if [[ ${PV} == "9999" ]]; then
			sed -e "s/@is_git_ver@/1/" -i "${T}/setup_d9vk_winelib.verb" || die
		fi

		# clean undefined
		sed -e "s/@.*@//" -i "${T}/setup_d9vk_winelib.verb" || die

	    # install winetricks verb
	    insinto "/usr/share/d9vk-${PV}"
	    doins "${T}/setup_d9vk_winelib.verb"

	    # create combined setup helper
	    exeinto /usr/bin
	    doexe "${T}/d9vk-setup-${PV}"
	fi

	einstalldocs
}