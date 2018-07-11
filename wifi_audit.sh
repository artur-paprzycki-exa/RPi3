
#!/bin/bash
exec 1> >(logger --size 64k -t $(basename $0)) 2>&1

iwlist wlan0 scanning | awk -F '[ :=]+' '/(Cell|SSID|Freq|Qual|IEEE)/{gsub(/^[ \t]+/,"",$0); printf $0"," } /Encr/{gsub(/^[ \t]+/,"",$0);  print $0}'
# gsub - removes spaces from output; $0 full string as result with matching word. To get reult after keyword use $1,$2...$6 etc. 
