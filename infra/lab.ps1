# lab.ps1 - Liga/desliga as VMs do laboratorio DBA (Vagrant)
# Uso: botao direito > "Executar com o PowerShell"
#      ou no PowerShell: powershell -ExecutionPolicy Bypass -File C:\lab\lab.ps1

$LabDir = "C:\Users\roger\OneDrive\lab"
$Todas  = @("ctl", "db1", "db2", "db3")

Set-Location $LabDir

function Mostrar-Status {
    Write-Host ""
    Write-Host "Estado atual das VMs:" -ForegroundColor Cyan
    vagrant status
}

function Escolher-Nos {
    Write-Host ""
    Write-Host "Nos disponiveis: $($Todas -join ', ')"
    $entrada = Read-Host "Digite os nos separados por espaco (ex: ctl db1 db2)"
    $nos = $entrada -split '\s+' | Where-Object { $_ -ne "" }
    $invalidos = $nos | Where-Object { $Todas -notcontains $_ }
    if ($invalidos) {
        Write-Host "No(s) invalido(s): $($invalidos -join ', ')" -ForegroundColor Red
        return @()
    }
    return $nos
}

while ($true) {
    Write-Host ""
    Write-Host "===== LAB DBA =====" -ForegroundColor Yellow
    Write-Host " 1) Subir TUDO (ctl, db1, db2, db3)"
    Write-Host " 2) Subir ctl + db1           (PostgreSQL basico)"
    Write-Host " 3) Subir ctl + db1 + db2     (replicacao)"
    Write-Host " 4) Escolher quais nos subir"
    Write-Host " 5) Desligar TUDO (halt)"
    Write-Host " 6) Suspender TUDO (suspend)"
    Write-Host " 7) Ver status"
    Write-Host " 8) Entrar na ctl (ssh)"
    Write-Host " 0) Sair"
    $op = Read-Host "Opcao"

    switch ($op) {
        "1" { vagrant up @Todas }
        "2" { vagrant up ctl db1 }
        "3" { vagrant up ctl db1 db2 }
        "4" {
            $nos = Escolher-Nos
            if ($nos.Count -gt 0) { vagrant up @nos }
        }
        "5" { vagrant halt }
        "6" { vagrant suspend }
        "7" { Mostrar-Status }
        "8" { vagrant ssh ctl }
        "0" { exit }
        default { Write-Host "Opcao invalida." -ForegroundColor Red }
    }
}