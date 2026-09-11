# Leitura de estado atual do CPU (offsets CO, cores, scalar)
$ErrorActionPreference = "Continue"
$out = "C:\Workspace\tools-pbo\estado.txt"
$exe = "C:\Workspace\tools-pbo\ryzen-smu-cli\ryzen-smu-cli.exe"

"=== offsets por core logico (get-offsets-terse) ===" | Out-File $out
& $exe --get-offsets-terse 2>&1 | Out-File $out -Append
"=== physical cores ===" | Out-File $out -Append
& $exe --get-physical-cores 2>&1 | Out-File $out -Append
"=== enabled cores ===" | Out-File $out -Append
& $exe --get-enabled-cores 2>&1 | Out-File $out -Append
"=== pbo scalar ===" | Out-File $out -Append
& $exe --get-pbo-scalar 2>&1 | Out-File $out -Append
"=== fim ===" | Out-File $out -Append
