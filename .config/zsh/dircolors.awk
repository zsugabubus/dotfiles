BEGIN {
  delete terms
  delete coloricons
  delete colors
  delete icons
  firstterm=1
}
match($0, /^([^#]*)#.*$/, m) {
  $0=m[1]
}
/^\s*$/ {
    next
}
match($0, /^(\S*)\s*(.*)$/, m) {
  cmd=m[1]; $0=m[2]
  lclr=""
  icn=""
  rclr=""
  eerclr=""
}
cmd == "TERM" {
  if (firstterm) {
    firstterm=0
    if (length(colors) > 0) {
      for (t in terms)
        print "TERM " terms[t] ".colors"
      for (i in colors)
        print colors[i]
      delete colors
      print ""
    }

    if (length(icons) > 0) {
      for (t in terms)
        print "TERM " terms[t] ".icons"
      for (i in icons)
        print icons[i]
      delete icons
      print ""
    }

    for (t in terms)
      print "TERM " terms[t]
    for (i in coloricons)
      print coloricons[i]
    delete coloricons
    print ""

    print ""
    delete terms
  }
  terms[length(terms)+1]=$0;
  next
}
match($0, /^(.*?)\\e\[(.*)\s*$/, m) {
  rclr=m[2]; eerclr="\\e[" m[2]; $0=m[1]
}
match($0, /^([^m]*?)m(.*)$/, m) {
  lclr="x" m[1]; $0=m[2]
}
{
  if (length(lclr) == 0) {
    gsub(/\s+$/, "")
    lclr=$0
  } else {
    lclr=substr(lclr, 2)
    icn=$0
  }

  coloricons[length(coloricons)+1]=cmd " " lclr (length(icn) > 0 ? "m" : "") icn eerclr
  if (cmd == "LINK" && lclr == "target") {
    colors[length(colors)+1]=cmd " " lclr
    icons[length(icons)+1]=cmd " " lclr
  } else {
    if (length(rclr) > 0) {
      colors[length(colors)+1]=cmd " " rclr
    } else if (length(lclr) > 0)
      colors[length(colors)+1]=cmd " " lclr

    icons[length(icons)+1]=cmd " " (length(icn) ? icn : "empty")
  }
}
{ firstterm=1 }
