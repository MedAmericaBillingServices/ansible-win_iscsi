#!powershell
# Copyright (c) 2016 MedAmerica Billing Services, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# WANT_JSON
# POWERSHELL_COMMON

$params = Parse-Args $args

$state = Get-AnsibleParam -obj $params -name "state" -default "present" -validateset "present","absent"

$target_iqn = Get-AnsibleParam -obj $params -name "target_iqn" -failifempty $true
$target_ip = Get-AnsibleParam -obj $params -name "target_ip" -failifempty $true
$target_port = Get-AnsibleParam -obj $params -name "target_port" -failifempty $true
$source_ip = Get-AnsibleParam -obj $params -name "source_ip" -failifempty $true
$multipath = Get-AnsibleParam -obj $params -name "multipath" -default $false

$result = New-Object psobject @{
    target_iqn = $target_iqn
    target_ip = $target_ip
    target_port = $target_port
    source_ip = $source_ip
    multipath = $multipath
    changed = $false
}

$should_connect = $false

$connection = Get-IscsiConnection | Where-Object { $_.InitiatorAddress -eq $source_ip -and $_.TargetAddress -eq $target_ip -and $_.TargetPortNumber -eq $target_port }

if ($connection -ne $null) {
    $target = Get-IscsiTarget -IscsiConnection $connection | Where-Object { $_.NodeAddress -eq $target_iqn}
    if ($target -eq $null) {
        $should_connect = $true
    }
} else {
    $should_connect = $true
}

if ($state -eq "present" -and $should_connect -eq $false) {
    Exit-Json $result
} elseif ($state -eq "absent" -and $should_connect -eq $true) {
    Exit-Json $result
} elseif ($state -eq "present" -and $should_connect -eq $true) {
    Connect-IscsiTarget -NodeAddress $target_iqn`
                        -TargetPortalAddress $target_ip`
                        -TargetPortalPortNumber $target_port`
                        -InitiatorPortalAddress $source_ip`
                        -IsPersistent $true`
                        -IsMultipathEnabled $multipath

    $result.changed = $true
    Exit-Json $result
}