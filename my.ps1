#Damerau–Levenshtein distance for Powershell
# based on c# code from
#http://blog.softwx.net/2015/01/optimizing-damerau-levenshtein_15.html

function Get-DamLev
{
    [OutputType([int])]
    Param
    (
        # Param1 help description
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=0)]
        
        [string] 
        $s,

        # Param2 help description
        [Parameter(Mandatory=$true, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=1)]
        [string]
        $t,

        # Param3 help description
        [Parameter(Mandatory=$false, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=2)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(0,[int]::MaxValue)]
        [int]
        $maxDistance = [int]::MaxValue,
         # Param3 help description
        [Parameter(Mandatory=$false, 
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true, 
                   ValueFromRemainingArguments=$false, 
                   Position=3)]
        [string]
        $dn
    )
    $input2=$t
    if ([string]::IsNullOrEmpty($t) -and [string]::IsNullOrEmpty($s)) {return -1;}
    if ([string]::IsNullOrEmpty($t)) {if ($s.length -lt $maxDistance){$s.length}else{return -1;}}

    if ([string]::IsNullOrEmpty($s)) {if ($t.length -lt $maxDistance){$t.length}else{return -1;}}
    if ($s.Length -gt $t.Length) {
        $temp = $s; $s = $t; $t = $temp; # swap s and t
    }

    [int] $sLen = $s.Length; # this is also the minimun length of the two strings
    [int] $tLen = $t.Length;

    [int] $lenDiff = $tLen - $sLen;
    if (($maxDistance -lt 0) -or ($maxDistance -gt $tLen)) {
        $maxDistance = $tLen;
    } else { if ($lenDiff -gt $maxDistance) {return -1}};
    while (($sLen -gt 0) -and ($s[$sLen - 1] -eq $t[$tLen - 1])) { $sLen--; $tLen--; }
    
    [int] $start = 0;
    if (($s[0] -eq $t[0]) -or ($sLen -eq 0)) { # if there's a shared prefix, or all s matches t's suffix
        # prefix common to both strings can be ignored
        while (($start -lt $sLen) -and ($s[$start] -eq $t[$start])) {$start++};
        $sLen -= $start; # length of the part excluding common prefix and suffix
        $tLen -= $start;
 
        # if all of shorter string matches prefix and/or suffix of longer string, then
        # edit distance is just the delete of additional characters present in longer string
        if ($sLen -eq 0) { if ($tLen -le $maxDistance) {return $tLen}else {return -1}};
 
        $t = $t.Substring($start, $tLen); # faster than t[start+j] in inner loop below
    }

    [int] $lenDiff = $tLen - $sLen;
    if (($maxDistance -lt 0) -or ($maxDistance -gt $tLen)) {
        $maxDistance = $tLen;
    } else { if ($lenDiff -gt $maxDistance) {return -1}};
 
    $v0 = New-Object 'int[]' $tLen;
    $v2 = New-Object 'int[]' $tLen; # stores one level further back (offset by +1 position)
    for ($j = 0; $j -lt $maxDistance; $j++) {$v0[$j] = $j + 1};
    for (; $j -lt $tLen; $j++) {$v0[$j] = $maxDistance + 1};
 
    [int] $jStartOffset = $maxDistance - ($tLen - $sLen);
    [bool] $haveMax = $maxDistance -lt $tLen;
    [int] $jStart = 0;
    [int] $jEnd = $maxDistance;
    [char] $sChar = $s[0];
    [int] $current = 0;
    for ($i = 0; $i -lt $sLen; $i++) {
        [char] $prevsChar = $sChar;
        $sChar = $s[$start + $i];
        [char] $tChar = $t[0];
        [int] $left = $i;
        $current = $left + 1;
        [int] $nextTransCost = 0;
        # no need to look beyond window of lower right diagonal - maxDistance cells (lower right diag is i - lenDiff)
        # and the upper left diagonal + maxDistance cells (upper left is i)
        if ($i -gt $jStartOffset) { $jStart +=  1}
        if ($jEnd -lt $tLen) { $jEnd +=  1 }
        for ($j = $jStart; $j -lt $jEnd; $j++) {
            [int] $above = $current;
            [int] $thisTransCost = $nextTransCost;
            $nextTransCost = $v2[$j];
            $v2[$j] = $current = $left; # cost of diagonal (substitution)
            $left = $v0[$j];    # left now equals current cost (which will be diagonal at next iteration)
            [char] $prevtChar = $tChar;
            $tChar = $t[$j];
            if ($sChar -ne $tChar) {
                if ($left -lt $current) {$current = $left};   # insertion
                if ($above -lt $current) {$current = $above}; # deletion
                $current++;
                if (($i -ne 0) -and ($j -ne 0)       -and ($sChar -eq $prevtChar)      -and ($prevsChar -eq $tChar)) {
                    $thisTransCost++;
                    if ($thisTransCost -lt $current) {$current = $thisTransCost}; # transposition
                }
            }
            $v0[$j] = $current;
        }
        if ($haveMax -and ($v0[$i + $lenDiff] -gt $maxDistance)) {return -1};
    }
    if($current -le $maxDistance)  {
    return [PSCustomObject]@{
    Scoring = $current
    text1 = $s
    text2= $input2
    dn= $dn
    }
    
     } else {return -1}
}

function Select-DamLevString {
    [CmdletBinding()]
    param (
        # The search query.
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string] $Search,

        # The data you want to search through.
        [Parameter(Position = 1, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('In')]
        $Data,

        # Set to True (default) it will calculate the match score.
        [Parameter()]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(0,[int]::MaxValue)]
        [int]
        $maxDistance = [int]::MaxValue
    )

    BEGIN {
       
    }

    PROCESS {

               if ($Data.displayname.length -gt 0 -and $Search.length -gt 0){
            Get-DamLev -s $Data.displayname -t $Search -dn $Data.distinguishedname -maxDistance $maxDistance| where {$_.Scoring -gt 0}}
    }
}

