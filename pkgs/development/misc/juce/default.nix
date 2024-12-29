{
  lib,
  stdenv,
  fetchFromGitHub,
  makeDesktopItem,
  copyDesktopItems,

  # Native build inputs
  cmake,
  pkg-config,
  makeWrapper,

  # Dependencies
  alsa-lib,
  freetype,
  curl,
  libglvnd,
  webkitgtk_4_0,
  pcre2,
  libsysprof-capture,
  util-linuxMinimal,
  libselinux,
  libsepol,
  libthai,
  libdatrie,
  libXdmcp,
  lerc,
  libxkbcommon,
  libepoxy,
  libXtst,
  sqlite,
  fontconfig,
  ladspaH,
  dejavu_fonts,
  xorg,
  gtk3,
  glib,

  # Options
  buildExtras ? true,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "juce";
  version = "8.0.4";

  src = fetchFromGitHub {
    owner = "juce-framework";
    repo = "juce";
    rev = finalAttrs.version;
    hash = "sha256-iAueT+yHwUUHOzqfK5zXEZQ0GgOKJ9q9TyRrVfWdewc=";
  };

  patches = [
    # Adapted from https://gitlab.archlinux.org/archlinux/packaging/packages/juce/-/raw/4e6d34034b102af3cd762a983cff5dfc09e44e91/juce-6.1.2-cmake_install.patch
    # for Juce 8.0.4.
    ./juce-8.0.4-cmake_install.patch
  ];

  nativeBuildInputs =
    [
      cmake
      pkg-config
      makeWrapper
    ]
    ++ lib.optionals buildExtras [
      copyDesktopItems
    ];

  cmakeBuildType = "Debug";
  cmakeFlags = lib.optionals buildExtras [
    "-DJUCE_BUILD_EXTRAS=ON"
  ];

  buildInputs =
    [
      freetype # libfreetype.so
      curl # libcurl.so
      (lib.getLib stdenv.cc.cc) # libstdc++.so libgcc_s.so
      pcre2 # libpcre2.pc
      libsysprof-capture
      libthai
      libdatrie
      lerc
      libepoxy
      sqlite
    ]
    ++ lib.optionals buildExtras [
      ladspaH
    ]
    ++ lib.optionals stdenv.hostPlatform.isLinux [
      alsa-lib # libasound.so
      libglvnd # libGL.so
      webkitgtk_4_0 # webkit2gtk-4.0
      util-linuxMinimal
      libselinux
      libsepol
      libXdmcp
      libxkbcommon
      libXtst
      xorg.libX11
      xorg.libXext
      xorg.libXcursor
      xorg.libXinerama
      xorg.libXrender
      xorg.libXrandr
      gtk3
      glib
    ];

  propagatedBuildInputs = [
    fontconfig
    curl
  ];

  postPatch = lib.optionalString (stdenv.isDarwin && buildExtras) ''
    substituteInPlace extras/Build/CMake/JUCEHelperTargets.cmake --replace "-flto" ""
  '';

  desktopItems = lib.optionals buildExtras [
    (makeDesktopItem {
      name = "Projucer";
      desktopName = "Projucer";
      genericName = "JUCE project management tool";
      comment = "IDE for working with JUCE based projects";
      exec = "Projucer %f";
      icon = "juce.png";
      categories = [ "Development" ];
      mimeTypes = [ "application/x-juce" ];
      keywords = [
        "Development"
        "IDE"
        "C++"
      ];
    })
  ];

  postInstall = lib.optionalString buildExtras (
    let
      appCheck = isApp: isApp && stdenv.isDarwin;
      appSuffix = isApp: if appCheck isApp then ".app" else "";
      outDir = isApp: if appCheck isApp then "$out/Applications" else "$out/bin";
      artefactPath = name: isApp: "extras/${name}/${name}_artefacts/Debug/${name}${appSuffix isApp}";
      mvArtefact = name: isApp: "mv ${artefactPath name isApp} ${outDir isApp}";
    in
    ''
      ${lib.optionalString stdenv.isDarwin "mkdir $out/Applications"}

      ${mvArtefact "Projucer" true}
      wrapProgram ${outDir true}/Projucer${appSuffix true} \
              --suffix JUCE_FONT_PATH ';' "${dejavu_fonts}/share/fonts/truetype/" \
              --prefix LD_LIBRARY_PATH : "${
                lib.makeLibraryPath [
                  # all of these libraries are probed dynamically by JUCE (`DynamicLibrary xLib {"libX11.so.6"}`)
                  curl
                  fontconfig
                  xorg.libX11
                  xorg.libXext
                  xorg.libXcursor
                  xorg.libXinerama
                  xorg.libXrender
                  xorg.libXrandr
                  gtk3
                  glib
                ]
              }"
      ${mvArtefact "NetworkGraphicsDemo" true}
      ${mvArtefact "AudioPluginHost" true}
      ${mvArtefact "AudioPerformanceTest" true}
      ${mvArtefact "UnitTestRunner" false}
      ${mvArtefact "BinaryBuilder" false}
      mkdir -p $out/share/pixmaps
      cp $src/extras/Projucer/Source/BinaryData/Icons/juce_icon.png $out/share/pixmaps/juce.png
    ''
  );

  meta = with lib; {
    description = "Cross-platform C++ application framework";
    mainProgram = "juceaide";
    longDescription = "Open-source cross-platform C++ application framework for creating desktop and mobile applications, including VST, VST3, AU, AUv3, AAX and LV2 audio plug-ins";
    homepage = "https://juce.com/";
    changelog = "https://github.com/juce-framework/JUCE/blob/${finalAttrs.version}/CHANGE_LIST.md";
    license = with licenses; [
      agpl3Only # Or alternatively the JUCE license, but that would not be included in nixpkgs then
    ];
    maintainers = with maintainers; [ kashw2 ];
    platforms = platforms.all;
  };
})
