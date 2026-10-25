%global appid io.github.royoshi.fexicoupdater

Name:           fe-xico-updater
Version:        0.1.0
Release:        1%{?dist}
Summary:        Update your system

License:        GPL-2.0-or-later AND BSD-3-Clause AND CC0-1.0
URL:            https://github.com/RoYoshi/FE-Xico-Updater
Source0:        %{url}/archive/refs/tags/%{version}.tar.gz

Packager:       FE-Xico project <https://github.com/RoYoshi>

BuildRequires:  desktop-file-utils
BuildRequires:  libappstream-glib
BuildRequires:  systemd-rpm-macros

BuildRequires:  cmake
BuildRequires:  extra-cmake-modules
BuildRequires:  kf6-rpm-macros
BuildRequires:  cmake(SDL3)
BuildRequires:  cmake(Qt6Core)
BuildRequires:  cmake(Qt6DBus)
BuildRequires:  cmake(Qt6Gui)
BuildRequires:  cmake(Qt6Qml)
BuildRequires:  cmake(Qt6QuickControls2)
BuildRequires:  cmake(Qt6Svg)
BuildRequires:  cmake(Qt6Widgets)

BuildRequires:  cmake(KF6Kirigami)
BuildRequires:  cmake(KF6CoreAddons)
BuildRequires:  cmake(KF6Config)
BuildRequires:  cmake(KF6ColorScheme)
BuildRequires:  cmake(KF6I18n)
BuildRequires:  cmake(KF6IconThemes)
BuildRequires:  cmake(KF6KirigamiAddons)


Requires:       kf6-kirigami%{?_isa}
Requires:       kf6-kirigami-addons%{?_isa}
Requires:       kf6-qqc2-desktop-style%{?_isa}
Requires:       qt6-controllable%{?_isa}
Requires:       qqc2-breeze-style%{?_isa}
Requires:       hicolor-icon-theme
Requires:       systemd%{?_isa} >= 258

Provides:       fe-xico-updater = %{version}-%{release}

%description
This is a convenient, easy-to-use interface for updating a Linux system.
Configured for FE-Xico while retaining the upstream service integration.
- Simple and powerful
- Full support for all input types (keyboard/mouse, controller, touchscreen)
- Configurable update and update-rollback commands

%prep
%autosetup

%build
%cmake

%build
%cmake_build

%install
%cmake_install
%find_lang fe-xico-updater

%check
appstream-util validate-relax --nonet %{buildroot}%{_kf6_metainfodir}/%{appid}.*.xml || :
desktop-file-validate %{buildroot}%{_kf6_datadir}/applications/%{appid}.desktop

%files -f fe-xico-updater.lang
%license LICENSES/{BSD-3-Clause.txt,CC0-1.0.txt,GPL-2.0-or-later.txt}
%doc README.md
%{_bindir}/fe-xico-updater
%{_appsdir}/%{appid}.desktop
%{_metainfodir}/%{appid}.*.xml
%{_scalableiconsdir}/%{appid}.svg
%config(noreplace) %{_sysconfdir}/%{name}/config.ini
%{_sysconfdir}/%{name}

%changelog
* Sat Jul 04 2026 Robert French - 0.8.0
- Added config file support

* Thu Feb 05 2026 Robert French
- Initial rpm build of FE-Xico Updater
