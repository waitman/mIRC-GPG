; mirc-gpg by Phil Lavin (0x3FFC291A) & Allan Jude (0x7F697DBA)
; SVN: $Id$
; modified by Waiman Gobble <uzimac@da3m0n8t3r.com>

alias gpg.setver {
  set %gpg.scriptver 0.9
}

alias gpg.updatever {
  if ($file($script).mtime != %gpg.scriptmtime) {
    set %gpg.scriptmtime $file($script).mtime
    gpg.setver
  }
}

menu status,channel,query,nicklist,menubar {
  -
  mIRC-GPG
  .Automatic Decryption
  ..$iif($group(#gpg).status == on,$style(1)) Enable:.enable #gpg
  ..$iif($group(#gpg).status == off,$style(1)) Disable:.disable #gpg
  .Generate a new Key:runapp cmd /c %gpg.path $+ gpg2.exe --gen-key
  ;.Upload my Keys:runapp cmd /c %gpg.path $+ gpg2.exe --keyserver keys.gnupg.net --send-keys ; doesn't work yet.. umm should work with a running keyserver?
  .Refresh my Keys:echo -at Refreshing keys from keys.gnupg.net please wait... | runapphidden cmd /c %gpg.path $+ gpg2.exe --keyserver keys.gnupg.net --refresh-keys | echo -at All keys have been refreshed
  .Search for Keys:runapp cmd /c %gpg.path $+ gpg2.exe --keyserver keys.gnupg.net --search-keys $$?="Search Parameters (Email is best)"
  ;.Set Key Trust: ;not implemented
}

on *:load:{
  gpg.setver

  if (!$isdir($scriptdir $+ gpg)) {
    runapphidden cmd /c mkdir " $+ $scriptdir $+ gpg $+ "
  }
  if (!$isdir($scriptdir $+ gpg\textin)) {
    runapphidden cmd /c mkdir " $+ $scriptdir $+ gpg\textin $+ "
  }

  if ($isfile(C:\Program Files\GNU\GnuPG\gpg2.exe)) {
    set %gpg.path $shortfn(C:\Program Files\GNU\GnuPG\)
    echo -at GPG Found At C:\Program Files\GNU\GnuPG\
  }
  elseif ($isfile(C:\Program Files (x86)\GNU\GnuPG\gpg2.exe)) {
    set %gpg.path $shortfn(C:\Program Files (x86)\GNU\GnuPG\)
    echo -at GPG Found At C:\Program Files (x86)\GNU\GnuPG\
  }
  else {
    set %gpg.path $shortfn($sdir(C:\, Please choose the directory where gpg2.exe was installed to))
  }
}

on *:START:{
  gpg.setver

  .timergpgverupdate 0 60 gpg.updatever
}

alias runAppHidden {
  set %gpg.runname rah $+ $rand(a,z) $+ $rand(a,z) $+ $rand(a,z) $+ $rand(a,z)

  .comopen %gpg.runname WScript.Shell
  .comclose %gpg.runname $com(%gpg.runname, Run, 1, *bstr, $$1-, int, 0, bool, true)
}

alias runApp {
  set %gpg.runname rah $+ $rand(a,z) $+ $rand(a,z) $+ $rand(a,z) $+ $rand(a,z)

  .comopen %gpg.runname WScript.Shell
  .comclose %gpg.runname $com(%gpg.runname, Run, 1, *bstr, $$1-, int, 3, bool, true)
}

alias runAppMin {
  set %gpg.runname rah $+ $rand(a,z) $+ $rand(a,z) $+ $rand(a,z) $+ $rand(a,z)

  .comopen %gpg.runname WScript.Shell
  .comclose %gpg.runname $com(%gpg.runname, Run, 1, *bstr, $$1-, int, 7, bool, true)
}

alias f8 {
  gpgEncrypt
}

alias gpgEncrypt {
  if (!$editbox($active, 0)) {
    echo -a No Text To Send
  }
  else {
    who $me
    $dialog(spk, selPubKey)

    if (%gpg.halt == $null) {
      set %gpg.sourcefile $scriptdir $+ gpg\source.txt
      set %gpg.destfile $scriptdir $+ gpg\dest.gpg
      set %gpg.outfile $scriptdir $+ gpg\out.txt

      write -c " $+ %gpg.sourcefile $+ " $editbox($active, 0)

      runapp cmd /c %gpg.path $+ gpg2.exe -e -a %gpg.recir(1)
      }
      inc %gpg.i
    }

    runapphidden cmd /c del " $+ $4- $+ *" /Q
  }
}

alias addKeysToSPK {
  set %gpg.keyfile $scriptdir $+ gpg\keylist.txt

  if ($1 == $null) {
    runapphidden cmd /c %gpg.path $+ gpg2.exe --list-keys > " $+ %gpg.keyfile $+ "
  }
  else {
    runapphidden cmd /c %gpg.path $+ gpg2.exe --list-keys " $+ $1- $+ " > " $+ %gpg.keyfile $+ "
  }

  ; Reset $readn - is there a better way?
  set %gpg.random $read(%gpg.keyfile, 1)
  unset %gpg.random

  set %gpg.readn 0

  while ($readn != 0) {
    set %gpg.line $read(%gpg.keyfile, s, uid, $calc(%gpg.readn + 1))

    if ($readn != 0) {
      did -a spk 1 %gpg.line
      set %gpg.readn $readn
    }
  }
}

on *:dialog:spk:init:*:{
  if (%gpg.searchstr == $null) {
    addKeysToSPK
  }
  else {
    addKeysToSPK %gpg.searchstr
    did -a spk 4 %gpg.searchstr
  }
}

on *:dialog:spk:sclick:*:{
  if ($did == 3) {
    set %gpg.halt 1
  }
  elseif ($did == 5) {
    did -r spk 1
    set %gpg.searchstr $did(4).text
    addkeystospk %gpg.searchstr
  }
  elseif ($did == 2) {
    set %gpg.i 1
    set %gpg.checkCount 0

    while (%gpg.i <= $did(1).lines) {
      if ($did(1, %gpg.i).cstate == 1) {
        inc %gpg.checkCount
      }

      inc %gpg.i
    }

    if (%gpg.checkCount == 0) {
      echo -at No key was selected
      set %gpg.halt 1
    }
    else {
      set %gpg.i 1
      set %gpg.recipients $null

      while (%gpg.i <= $did(1).lines) {
        if ($did(1, %gpg.i).cstate == 1 || $did(1, %gpg.i).state == 1) {
          set %gpg.revitem $rev($did(1, %gpg.i))
          set %gpg.emailstart $pos(%gpg.revitem, >, 1)
          set %gpg.emailend $pos(%gpg.revitem, <, 1)

          set %gpg.recipients %gpg.recipients -r $rev($mid(%gpg.revitem, $calc(%gpg.emailstart + 1), $calc(%gpg.emailend - %gpg.emailstart - 1)))
        }

        inc %gpg.i
      }
    }
  }
  elseif ($did == 6) {
    set %gpg.i 1

    while (%gpg.i <= $did(1).lines) {
      if ($did(6).state == 1) {
        did -s spk 1 %gpg.i
      }
      else {
        did -l spk 1 %gpg.i
      }

      inc %gpg.i
    }
  }
  elseif ($did == 1) {
    set %gpg.i 1
    set %gpg.checkAll 1

    while (%gpg.i <= $did(1).lines) {
      if ($did(1, %gpg.i).cstate == 0) {
        set %gpg.checkAll 0
      }

      inc %gpg.i
    }

    if (%gpg.checkAll == 1) {
      did -c spk 6
    }
    else {
      did -u spk 6
    }
  }
}

dialog selPubKey {

  title "Select Public Key"

  size -1 -1 250 170

  option dbu

  edit "", 4, 10 10 190 10
  button "Search", 5, 205 8 35 14, default

  check "Select/Deselect All", 6, 12 25 100 10

  list 1, 10 37 230 100, multsel check result

  button "OK", 2, 65 142 50 20, ok %gpg.okbut
  button "Cancel", 3, 125 142 50 20, cancel %gpg.cancelbut
}

alias dodel {
  if (%gpg.textin. [ $+ [ $1 $+ .  [ $+ [ $2 ] ] ] ] == $null) {
    runapphidden cmd /c del " $+ $scriptdir $+ gpg\textin\ $+ $1 $+ - $+ $2 $+ .*" /Q
    .timergpg $+ . $+ $1 $+ . $+ $2 off
    dec %gpg.incount 1
    if (%gpg.incount <= 0) {
      disable #gpg.capture
    }
  }
}

#gpg on
on 1:TEXT:-----BEGIN PGP MESSAGE-----:*:{
  set -u10 %gpg.textin. [ $+ [ $network $+ .  [ $+ [ $nick ] ] ] ] 1
  write -c " $+ $scriptdir $+ gpg\textin\ $+ $network $+ - $+ $nick $+ .txt.gpg $+ " $1-
  .timergpg $+ . $+ $network $+ . $+ $nick 0 1 dodel $network $nick
  .enable #gpg.capture
  if (%gpg.incount < 0) {
    set %gpg.incount 0
  }
  inc %gpg.incount 1
}

on 1:TEXT:-----END PGP MESSAGE-----:*:{
  if (%gpg.textin. [ $+ [ $network $+ .  [ $+ [ $nick ] ] ] ] != $null) {
    .timergpg $+ . $+ $network $+ . $+ $nick off
    unset %gpg.textin. [ $+ [ $network $+ .  [ $+ [ $nick ] ] ] ]
    write " $+ $scriptdir $+ gpg\textin\ $+ $network $+ - $+ $nick $+ .txt.gpg $+ " $1-
  }
  dec %gpg.incount 1
  if (%gpg.incount <= 0) {
    .disable #gpg.capture
  }

  if ($chan != $null) {
    set %gpg.src $chan
  }
  else {
    set %gpg.src $nick
  }

  gpgdecrypt $nick %gpg.src $network $scriptdir $+ gpg\textin\ $+ $network $+ - $+ $nick $+ .txt.gpg
}
#gpg end

#gpg.capture off
on 1:TEXT:*:*:{
  if ($1 != -----END PGP MESSAGE-----) {
    if (%gpg.textin. [ $+ [ $network $+ .  [ $+ [ $nick ] ] ] ] != $null) {
      set -u10 %gpg.textin. [ $+ [ $network $+ .  [ $+ [ $nick ] ] ] ] 1
      if ($pos($1-,!,0) > 0) {
        write " $+ $scriptdir $+ gpg\textin\ $+ $network $+ - $+ $nick $+ .txt.gpg $+ " $replace($replace($1-,~!,$chr(10)),!,$chr(10))
      }
      elseif ($pos($1-,~,0) > 0) {
        write " $+ $scriptdir $+ gpg\textin\ $+ $network $+ - $+ $nick $+ .txt.gpg $+ " $replace($1-,~,$chr(10))
      }
      elseif ($1- != ~) {
        write " $+ $scriptdir $+ gpg\textin\ $+ $network $+ - $+ $nick $+ .txt.gpg $+ " $1-
      }
      else {
        write " $+ $scriptdir $+ gpg\textin\ $+ $network $+ - $+ $nick $+ .txt.gpg $+ " $chr(13)
      }
    }
  }
}
#gpg.capture end

; Update the IAL
on 1:NOTICE:Your vhost of *:?:{
  who $me
}

alias rev {
  if ($1) {
    set %gpg.c $strip($1-)
    set %gpg.a $len(%gpg.c)
    while (%gpg.a >= 1) {
      set %gpg.b %gpg.b $+ $replace($mid(%gpg.c,%gpg.a,1),$chr(32),$str($chr(32),2))
      dec %gpg.a
    }
  }
  set %gpg.o %gpg.b
  unset %gpg.a
  unset %gpg.b
  unset %gpg.c
  return %gpg.o
}
