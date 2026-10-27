{ pkgs, lib, ... }:
{
  environment.systemPackages = [
    pkgs.yubikey-manager
    (pkgs.writeShellApplication {
      name = "ssh-add-piv";
      text = ''
        set +u
        # export SSH_AUTH_SOCK="''${SSH_AUTH_SOCK:-$XDG_RUNTIME_DIR/ssh-agent}"
        export SSH_AUTH_SOCK="''${XDG_RUNTIME_DIR}/ssh-agent"
        
        if [ "$1" != "-f" ] && ssh-add -l 2>/dev/null | grep -q 'PIV Authentication'; then
          echo "YubiKey already in agent ('ssh-add-piv -f' to override)"
          exit 0
        fi
        
        ssh-add -e "${pkgs.yubico-piv-tool}/lib/libykcs11.so" >/dev/null 2>&1 || true
        exec ssh-add -s "${pkgs.yubico-piv-tool}/lib/libykcs11.so"
      '';
    })
  ];
  services.pcscd.enable = true;
  services.gnome.gcr-ssh-agent.enable = lib.mkForce false;
  programs.ssh.startAgent = true;
  programs.ssh.agentPKCS11Whitelist = "${pkgs.yubico-piv-tool}/lib/*";
}
