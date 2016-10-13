{ config, lib, pkgs, ... }@args: with config.krebs.lib; let

  cfg = config.lass.usershadow;

  out = {
    options.lass.usershadow = api;
    config = lib.mkIf cfg.enable imp;
  };

  api = {
    enable = mkEnableOption "usershadow";
    pattern = mkOption {
      type = types.str;
      default = "/home/%/.shadow";
    };
  };

  imp = {
    environment.systemPackages = [ usershadow ];
    security.pam.services.sshd.text = ''
      auth required pam_exec.so expose_authtok ${usershadow}/bin/verify ${cfg.pattern}
      auth required pam_permit.so
      account required pam_permit.so
      session required pam_permit.so
    '';

    security.pam.services.exim.text = ''
      auth required pam_exec.so expose_authtok ${usershadow}/bin/verify ${cfg.pattern}
      auth required pam_permit.so
      account required pam_permit.so
      session required pam_permit.so
    '';
  };

  usershadow = let {
    deps = [
      "pwstore-fast"
      "bytestring"
    ];
    body = pkgs.writeHaskell "passwords" {
      executables.verify = {
        extra-depends = deps;
        text = ''
          import Data.Monoid
          import System.IO
          import Data.Char (chr)
          import System.Environment (getEnv, getArgs)
          import Crypto.PasswordStore (verifyPasswordWith, pbkdf2)
          import qualified Data.ByteString.Char8 as BS8
          import System.Exit (exitFailure, exitSuccess)

          main :: IO ()
          main = do
            user <- getEnv "PAM_USER"
            shadowFilePattern <- head <$> getArgs
            let shadowFile = lhs <> user <> tail rhs
                (lhs, rhs) = span (/= '%') shadowFilePattern
            hash <- readFile shadowFile
            password <- takeWhile (/= (chr 0)) <$> hGetLine stdin
            let res = verifyPasswordWith pbkdf2 (2^) (BS8.pack password) (BS8.pack hash)
            if res then exitSuccess else exitFailure
        '';
      };
      executables.passwd = {
        extra-depends = deps;
        text = ''
          import System.Environment (getEnv)
          import Crypto.PasswordStore (makePasswordWith, pbkdf2)
          import qualified Data.ByteString.Char8 as BS8
          import System.IO (stdin, hSetEcho, putStr)

          main :: IO ()
          main = do
            home <- getEnv "HOME"
            putStr "password:"
            hSetEcho stdin False
            password <- BS8.hGetLine stdin
            hash <- makePasswordWith pbkdf2 password 10
            BS8.writeFile (home ++ "/.shadow") hash
        '';
      };
    };
  };

in out