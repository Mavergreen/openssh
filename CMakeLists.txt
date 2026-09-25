cmake_minimum_required(VERSION 3.16)
# Builds the Cocoa/ObjC Sparkle updater .app for the OpenSSH-for-Mavericks product. The OpenSSH
# binaries themselves are cross-built by build/*.sh; this target is only the updater. x86_64 /
# min-10.9 because the updater runs on the 10.9 box. No product linkage (asserted at package time).
set(CMAKE_OSX_DEPLOYMENT_TARGET 10.9 CACHE STRING "runs on 10.9")
set(CMAKE_OSX_ARCHITECTURES x86_64 CACHE STRING "Intel-only (10.9)")

project(OpenSSHUpdater LANGUAGES OBJC)

find_package(MavericksShipyard REQUIRED)
include(Mavericks)
include(MavericksSparkle)

mavericks_resolve_version(MAVOSSH_VERSION)   # <upstream>-mavericks.N, from the shared Config

mavericks_add_updater_app(
  PRODUCT openssh
  PRODUCT_NAME "Mavericks OpenSSH"
  ALLOW_GENERIC   # ship the generic macOS app icon on purpose (no bespoke artwork; no Apple/OpenBSD mark)
  VERSION "${MAVOSSH_VERSION}"
  LOG_PREFIX "MavOpenSSHUpdater"
  CONFIRM_TITLE "Mavericks OpenSSH updated"
  CONFIRM_BODY "OpenSSH for Mavericks in /usr/local/mavergreen/openssh was updated."
  # no PANE_HINT_KEY -> background-found updates post an NSUserNotification (CLI product)
)
