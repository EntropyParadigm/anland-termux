TERMUX_PKG_HOMEPAGE=https://github.com/lfdevs/anland-termux
TERMUX_PKG_DESCRIPTION="Anland display daemon and session helpers for Termux"
TERMUX_PKG_LICENSE="MIT"
TERMUX_PKG_MAINTAINER="@lfdevs"
TERMUX_PKG_VERSION=0.1.0
TERMUX_PKG_SKIP_SRC_EXTRACT=true
TERMUX_PKG_DEPENDS="proot-distro"

termux_step_make() {
	local repo_root
	repo_root="$(realpath "$TERMUX_PKG_BUILDER_DIR/../..")"

	$CC $CPPFLAGS $CFLAGS -Wall -Wextra -Wpedantic -std=c11 \
		"$repo_root/termux/anland/anland.c" \
		"$repo_root/termux/anland/common/socket_utils.c" \
		-o anland \
		$LDFLAGS
}

termux_step_make_install() {
	local repo_root
	repo_root="$(realpath "$TERMUX_PKG_BUILDER_DIR/../..")"

	install -Dm700 anland "$TERMUX_PREFIX/bin/anland"
	install -Dm700 "$repo_root/scripts/anland-native-session.sh" \
		"$TERMUX_PREFIX/bin/anland-native-session"
	install -Dm700 "$repo_root/scripts/anland-proot-session.sh" \
		"$TERMUX_PREFIX/bin/anland-proot-session"
}
