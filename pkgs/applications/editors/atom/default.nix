{ stdenv, pkgs, fetchurl, lib, makeWrapper, gvfs, atomEnv}:

let
  common = pname: {version, sha256}: stdenv.mkDerivation rec {
    name = "${pname}-${version}";
    inherit version;

    src = fetchurl {
      url = "https://github.com/atom/atom/releases/download/v${version}/atom-amd64.deb";
      name = "${name}.deb";
      inherit sha256;
    };

    nativeBuildInputs = [ makeWrapper ];

    buildCommand = ''
      mkdir -p $out/usr/
      ar p $src data.tar.xz | tar -C $out -xJ ./usr
      substituteInPlace $out/usr/share/applications/${pname}.desktop \
        --replace /usr/share/${pname} $out/bin
      mv $out/usr/* $out/
      rm -r $out/share/lintian
      rm -r $out/usr/
      # sed -i "s/'${pname}'/'.${pname}-wrapped'/" $out/bin/${pname}
      wrapProgram $out/bin/${pname} \
        --prefix "PATH" : "${gvfs}/bin"

      fixupPhase

      share=$out/share/${pname}

      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath "${atomEnv.libPath}:$share" \
        $share/atom
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        --set-rpath "${atomEnv.libPath}" \
        $share/resources/app/apm/bin/node
      patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        $out/share/atom/resources/app.asar.unpacked/node_modules/symbols-view/vendor/ctags-linux

      dugite=$share/resources/app.asar.unpacked/node_modules/dugite
      rm -f $dugite/git/bin/git
      ln -s ${pkgs.git}/bin/git $dugite/git/bin/git
      rm -f $dugite/git/libexec/git-core/git
      ln -s ${pkgs.git}/bin/git $dugite/git/libexec/git-core/git

      find $share -name "*.node" -exec patchelf --set-rpath "${atomEnv.libPath}:$share" {} \;

      paxmark m $share/atom
      paxmark m $share/resources/app/apm/bin/node
    '';

    meta = with stdenv.lib; {
      description = "A hackable text editor for the 21st Century";
      homepage = https://atom.io/;
      license = licenses.mit;
      maintainers = with maintainers; [ offline nequissimus synthetica ysndr ];
      platforms = platforms.x86_64;
    };
  };
in stdenv.lib.mapAttrs common {
  atom = {
    version = "1.27.2";
    sha256 = "0xriv142asc82mjxzkqsafaqalxa3icz4781z2fsgyfkkw6zbz2v";
  };

  atom-beta = {
    version = "1.28.0-beta3";
    sha256 = "07mmzkbc7xzcwh6ylrs2w1g3l5gmyfk0gdmr2kzr6jdr00cq73y0";
  };
}
