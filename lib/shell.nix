{ lib, ... }:

with lib;

rec {
  escape =
    let
      isSafeChar = c: match "[-+./0-9:=A-Z_a-z]" c != null;
    in
    stringAsChars (c:
      if isSafeChar c then c
      else if c == "\n" then "'\n'"
      else "\\${c}");

  #
  # shell script generators
  #

  # example: "${cat (toJSON { foo = "bar"; })} | jq -r .foo"
  cat = s: "printf '%s' ${escape s}";
}