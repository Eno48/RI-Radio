$Root = $PSScriptRoot
$DataFile = Join-Path $Root "data\state.json"
$ShareUrl = ""
Add-Type -AssemblyName System.Web.Extensions
$Serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$Serializer.MaxJsonLength = 20000000
$Serializer.RecursionLimit = 32

function To-JsonText($obj) {
  return $Serializer.Serialize((For-Json $obj))
}

function Unwrap-Json($value) {
  if ($null -eq $value) { return $null }
  $base = $value
  if ($value -is [psobject] -and $null -ne $value.PSObject.BaseObject) { $base = $value.PSObject.BaseObject }
  return ,$base
}

function For-Json($obj) {
  if ($null -eq $obj) { return $null }
  $obj = Unwrap-Json $obj
  if ($obj -is [string] -or $obj -is [bool] -or $obj -is [int] -or $obj -is [long] -or $obj -is [double] -or $obj -is [decimal]) {
    return $obj
  }
  if ($obj -is [System.Collections.IDictionary]) {
    $dict = New-Object "System.Collections.Generic.Dictionary[string,object]"
    foreach ($key in @($obj.Keys)) {
      [void]$dict.Add([string]$key, (Unwrap-Json (For-Json $obj[$key])))
    }
    return ,$dict
  }
  if ($obj -is [System.Collections.IEnumerable]) {
    $items = New-Object System.Collections.ArrayList
    foreach ($item in $obj) { [void]$items.Add((Unwrap-Json (For-Json $item))) }
    return ,$items
  }
  return [string]$obj
}

function Convert-ToEditable($obj) {
  if ($null -eq $obj) { return $null }
  if ($obj -is [string] -or $obj -is [bool] -or $obj -is [int] -or $obj -is [long] -or $obj -is [double] -or $obj -is [decimal]) {
    return $obj
  }
  if ($obj -is [System.Collections.IDictionary]) {
    $hash = @{}
    foreach ($key in @($obj.Keys)) { $hash[$key] = Convert-ToEditable $obj[$key] }
    return $hash
  }
  if ($obj -is [System.Management.Automation.PSCustomObject]) {
    $hash = @{}
    foreach ($prop in $obj.PSObject.Properties) { $hash[$prop.Name] = Convert-ToEditable $prop.Value }
    return $hash
  }
  if ($obj -is [System.Collections.IEnumerable]) {
    $list = New-Object System.Collections.Generic.List[object]
    foreach ($item in $obj) { [void]$list.Add((Convert-ToEditable $item)) }
    return ,$list
  }
  return $obj
}

function Ensure-List($value) {
  if ($value -is [System.Collections.Generic.List[object]]) { return ,$value }
  $list = New-Object System.Collections.Generic.List[object]
  if ($null -eq $value) { return ,$list }
  foreach ($item in @($value)) {
    if ($null -ne $item) { [void]$list.Add($item) }
  }
  return ,$list
}

function Normalize-State($raw) {
  $editable = Convert-ToEditable $raw
  if (-not $editable.names) { $editable.names = @{} }
  if (-not $editable.posts) { $editable.posts = @{} }
  foreach ($board in @("square", "night", "work")) {
    $posts = Ensure-List $editable.posts[$board]
    foreach ($post in $posts) {
      $post.images = Ensure-List $post.images
      $post.likedBy = Ensure-List $post.likedBy
      $post.replies = Ensure-List $post.replies
    }
    $editable.posts[$board] = $posts
  }
  $devices = @{}
  if ($editable.devices) {
    foreach ($key in @($editable.devices.Keys)) {
      $device = $editable.devices[$key]
      if (-not $device) { continue }
      $devices[[string]$key] = @{
        code = [string]$device.code
        active = [int]$device.active
        aliases = Ensure-List $device.aliases
        history = Ensure-List $device.history
      }
    }
  }
  $editable.devices = $devices
  return $editable
}

function Save-State {
  $dir = Split-Path $DataFile
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $json = To-JsonText @{ names = $State.names; posts = $State.posts; devices = $State.devices }
  [System.IO.File]::WriteAllText($DataFile, $json, [System.Text.UTF8Encoding]::new($false))
}

if (Test-Path $DataFile) {
  $raw = [System.IO.File]::ReadAllText($DataFile, [System.Text.UTF8Encoding]::new($false)) | ConvertFrom-Json
  $State = Normalize-State $raw
} else {
  $State = Normalize-State (@{
    names = @{
      "茶水" = "system"; "窗边" = "system"; "信号" = "system"
      "值夜" = "system"; "灯" = "system"; "扳手" = "system"; "仓库" = "system"
    }
    posts = @{
      square = @(
        @{ id = "p1"; clientId = "system"; alias = 0; name = "茶水"; avatar = ""; text = "休息室新到了一箱橘子。想拿的人直接来，不用打招呼。"; images = @(); time = "今天 09:20"; likedBy = @(); replies = @(@{ clientId = "system"; alias = 0; name = "窗边"; avatar = ""; text = "我下午过去，帮你留两个。" }) },
        @{ id = "p2"; clientId = "system"; alias = 0; name = "信号"; avatar = ""; text = "靠窗的位子空着。谁要是走累了，过来坐一会儿。"; images = @(); time = "今天 11:05"; likedBy = @(); replies = @() }
      )
      night = @(
        @{ id = "p3"; clientId = "system"; alias = 0; name = "值夜"; avatar = ""; text = "今天的云很好看。想配图的人，直接发在这个版块。"; images = @(); time = "昨天 23:40"; likedBy = @(); replies = @(@{ clientId = "system"; alias = 0; name = "灯"; avatar = ""; text = "我先留一句，等你的图。" }) }
      )
      work = @(
        @{ id = "p4"; clientId = "system"; alias = 0; name = "仓库"; avatar = ""; text = "晚上八点缺一个人。想玩的直接回我，来得及。"; images = @(); time = "今天 08:10"; likedBy = @(); replies = @() }
      )
    }
  })
  Save-State
}
Save-State

function Write-Http($code, $contentType, $bytes) {
  $reason = "OK"
  if ($code -eq 400) { $reason = "Bad Request" }
  elseif ($code -eq 403) { $reason = "Forbidden" }
  elseif ($code -eq 404) { $reason = "Not Found" }
  elseif ($code -eq 409) { $reason = "Conflict" }
  elseif ($code -eq 413) { $reason = "Payload Too Large" }
  elseif ($code -ge 500) { $reason = "Error" }
  $header = "HTTP/1.1 $code $reason`r`nContent-Type: $contentType`r`nContent-Length: $($bytes.Length)`r`nCache-Control: no-store`r`nConnection: close`r`n`r`n"
  $head = [System.Text.Encoding]::ASCII.GetBytes($header)
  $script:ClientStream.Write($head, 0, $head.Length)
  if ($bytes.Length -gt 0) { $script:ClientStream.Write($bytes, 0, $bytes.Length) }
  $script:ClientStream.Flush()
}

function Send-Json($context, $obj, $code) {
  if (-not $code) { $code = 200 }
  $json = To-JsonText $obj
  if ([string]::IsNullOrEmpty($json)) { $json = "{}" }
  Write-Http $code "application/json; charset=utf-8" ([System.Text.Encoding]::UTF8.GetBytes($json))
}

function New-DeviceCode {
  $alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".ToCharArray()
  do {
    $chars = 1..6 | ForEach-Object { $alphabet[(Get-Random -Maximum $alphabet.Length)] }
    $code = -join $chars
    $taken = $false
    foreach ($key in @($State.devices.Keys)) {
      if ([string]$State.devices[$key].code -eq $code) { $taken = $true }
    }
  } while ($taken)
  return $code
}

function Remember-Device($clientId, $aliases, $active) {
  if (-not $State.devices) { $State.devices = @{} }
  $existing = $null
  if ($State.devices.ContainsKey($clientId)) { $existing = $State.devices[$clientId] }
  $code = ""
  if ($existing -and $existing.code) { $code = [string]$existing.code } else { $code = New-DeviceCode }
  $history = Ensure-List $(if ($existing) { $existing.history } else { $null })
  $State.devices[$clientId] = @{
    code = $code
    active = $active
    aliases = $aliases
    history = $history
  }
  return $code
}

function Add-History($clientId, $action, $detail) {
  if (-not $State.devices -or -not $State.devices.ContainsKey($clientId)) { return }
  $device = $State.devices[$clientId]
  $history = Ensure-List $device.history
  $text = [string]$detail
  if ($text.Length -gt 40) { $text = $text.Substring(0, 40) }
  [void]$history.Insert(0, @{ at = (Get-Date -Format "MM-dd HH:mm"); action = $action; detail = $text })
  while ($history.Count -gt 40) { $history.RemoveAt($history.Count - 1) }
  $device.history = $history
}

function Find-DeviceByCode($code) {
  $wanted = ([string]$code).Trim().ToUpper()
  if (-not $wanted -or -not $State.devices) { return $null }
  foreach ($key in @($State.devices.Keys)) {
    if ([string]$State.devices[$key].code -eq $wanted) {
      return @{ clientId = [string]$key; device = $State.devices[$key] }
    }
  }
  return $null
}

function Device-View($clientId, $device) {
  return @{
    clientId = $clientId
    code = [string]$device.code
    active = [int]$device.active
    aliases = $device.aliases
  }
}

function Public-State {
  $share = $ShareUrl
  $publicFile = Join-Path $Root "data\public-url.txt"
  if (Test-Path -LiteralPath $publicFile) {
    $public = ([System.IO.File]::ReadAllText($publicFile)).Trim()
    if ($public) { $share = $public }
  }
  return @{ names = $State.names; posts = $State.posts; share = $share }
}

function Read-Body($request) {
  $reader = New-Object System.IO.StreamReader($request.InputStream, [System.Text.Encoding]::UTF8)
  $text = $reader.ReadToEnd()
  $reader.Close()
  if ([string]::IsNullOrWhiteSpace($text)) { return $null }
  return $text | ConvertFrom-Json
}

function Find-Post($boardId, $postId) {
  if (-not $State.posts.ContainsKey($boardId)) { return $null }
  foreach ($post in $State.posts[$boardId]) {
    if ($post.id -eq $postId) { return $post }
  }
  return $null
}

function Alias-List($body) {
  $list = New-Object System.Collections.Generic.List[object]
  foreach ($alias in @($body.aliases)) {
    if ($null -eq $alias) { continue }
    [void]$list.Add(@{ name = ([string]$alias.name).Trim(); avatar = [string]$alias.avatar })
  }
  while ($list.Count -lt 2) { [void]$list.Add(@{ name = ""; avatar = "" }) }
  return ,$list
}

function Read-HttpRequest($stream) {
  $collected = New-Object System.IO.MemoryStream
  $buf = New-Object byte[] 8192
  $headerLen = -1
  while ($headerLen -lt 0) {
    $n = $stream.Read($buf, 0, $buf.Length)
    if ($n -le 0) { return $null }
    $collected.Write($buf, 0, $n)
    $raw = $collected.ToArray()
    for ($i = 0; $i -le $raw.Length - 4; $i++) {
      if ($raw[$i] -eq 13 -and $raw[$i + 1] -eq 10 -and $raw[$i + 2] -eq 13 -and $raw[$i + 3] -eq 10) {
        $headerLen = $i
        break
      }
    }
    if ($headerLen -lt 0 -and $collected.Length -gt 65536) { return $null }
  }
  $raw = $collected.ToArray()
  $headerText = [System.Text.Encoding]::ASCII.GetString($raw, 0, $headerLen)
  $lines = $headerText -split "`r`n"
  $parts = $lines[0] -split " "
  $target = "/"
  if ($parts.Length -gt 1 -and $parts[1]) { $target = $parts[1] }
  $contentLength = [int64]0
  foreach ($line in $lines) {
    if ($line -match '^(?i)Content-Length:\s*(\d+)') { $contentLength = [int64]$Matches[1] }
  }
  $body = New-Object System.IO.MemoryStream
  $bodyStart = $headerLen + 4
  if ($raw.Length -gt $bodyStart -and $contentLength -gt 0) {
    $take = [int]([Math]::Min([int64]($raw.Length - $bodyStart), $contentLength))
    if ($take -gt 0) { $body.Write($raw, $bodyStart, $take) }
  }
  while ($body.Length -lt $contentLength) {
    $n = $stream.Read($buf, 0, $buf.Length)
    if ($n -le 0) { break }
    $remain = [int]([Math]::Min($contentLength - $body.Length, [int64]$n))
    if ($remain -gt 0) { $body.Write($buf, 0, $remain) }
  }
  $body.Position = 0
  return @{
    HttpMethod = $parts[0]
    Url = (New-Object System.Uri ("http://localhost" + $target))
    ContentLength64 = $contentLength
    InputStream = $body
  }
}

$ips = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } |
  Select-Object -ExpandProperty IPAddress)
$shareIp = $ips | Where-Object { $_ -like "192.168.*" } | Select-Object -First 1
if (-not $shareIp) { $shareIp = $ips | Where-Object { $_ -like "10.*" } | Select-Object -First 1 }
if (-not $shareIp) { $shareIp = $ips | Select-Object -First 1 }
if ($shareIp) { $ShareUrl = "http://${shareIp}:8765" }

$tcp = New-Object System.Net.Sockets.TcpListener ([System.Net.IPAddress]::Any, 8765)
$tcp.Start()
Write-Output ("LISTENING http://127.0.0.1:8765/ " + (($ips | ForEach-Object { "http://${_}:8765/" }) -join " "))

$types = @{
  ".html" = "text/html; charset=utf-8"
  ".css" = "text/css; charset=utf-8"
  ".js" = "application/javascript; charset=utf-8"
}

while ($true) {
  $client = $tcp.AcceptTcpClient()
  $script:ClientStream = $client.GetStream()
  $script:ClientStream.ReadTimeout = 30000
  try {
    $request = Read-HttpRequest $script:ClientStream
    if (-not $request) { continue }
    $path = [System.Uri]::UnescapeDataString($request.Url.AbsolutePath)
    $method = $request.HttpMethod

    if ($path.StartsWith("/api/")) {
      if ($request.ContentLength64 -gt 12MB) {
        Send-Json $context @{ error = "图片太大，请换小一点的。" } 413
        continue
      }
      $body = $null
      if ($method -eq "POST") { $body = Read-Body $request }

      if ($path -eq "/api/state" -and $method -eq "GET") {
        Send-Json $context (Public-State)
        continue
      }

      if ($path -eq "/api/device" -and $method -eq "GET") {
        $id = ""
        $query = $request.Url.Query.TrimStart("?")
        foreach ($part in ($query -split "&")) {
          if ($part.StartsWith("id=")) { $id = [System.Uri]::UnescapeDataString($part.Substring(3)) }
        }
        if ($State.devices -and $id -and $State.devices.ContainsKey($id)) {
          Send-Json $context @{ device = (Device-View $id $State.devices[$id]) }
        } else {
          Send-Json $context @{ device = $null }
        }
        continue
      }

      if ($path -eq "/api/return" -and $method -eq "POST") {
        $found = Find-DeviceByCode $body.code
        if (-not $found) {
          Send-Json $context @{ error = "没有这个回站编号。" } 404
          continue
        }
        Add-History $found.clientId "回来" "用回站编号进入"
        Save-State
        Send-Json $context (Device-View $found.clientId $found.device)
        continue
      }

      if ($path -eq "/api/profile" -and $method -eq "POST") {
        $clientId = [string]$body.clientId
        $aliases = Alias-List $body
        $wanted = @($aliases | ForEach-Object { $_.name } | Where-Object { $_ })
        if (($wanted | Select-Object -Unique).Count -ne $wanted.Count) {
          Send-Json $context @{ error = "两个名字不能完全一样，换一个编号。" } 409
          continue
        }
        $conflict = ""
        foreach ($name in $wanted) {
          if ($State.names.ContainsKey($name) -and $State.names[$name] -ne $clientId) { $conflict = $name; break }
        }
        if ($conflict) {
          Send-Json $context @{ error = "「$conflict」已经有人用了，换一个编号。" } 409
          continue
        }
        $owned = @($State.names.Keys | Where-Object { $State.names[$_] -eq $clientId })
        foreach ($name in $owned) { [void]$State.names.Remove($name) }
        foreach ($alias in $aliases) {
          if ($alias.name) { $State.names[$alias.name] = $clientId }
        }
        foreach ($board in @("square", "night", "work")) {
          foreach ($post in $State.posts[$board]) {
            if ($post.clientId -eq $clientId) {
              $slot = 0
              if ($post.alias -eq 1) { $slot = 1 }
              if ($aliases[$slot].name) {
                $post.name = $aliases[$slot].name
                $post.avatar = $aliases[$slot].avatar
              }
            }
            foreach ($reply in $post.replies) {
              if ($reply.clientId -eq $clientId) {
                $slot = 0
                if ($reply.alias -eq 1) { $slot = 1 }
                if ($aliases[$slot].name) {
                  $reply.name = $aliases[$slot].name
                  $reply.avatar = $aliases[$slot].avatar
                }
              }
            }
          }
        }
        $active = 0
        if ([int]$body.active -eq 1) { $active = 1 }
        $code = Remember-Device $clientId $aliases $active
        $named = @($aliases | ForEach-Object { $_.name } | Where-Object { $_ })
        Add-History $clientId "资料" ($named -join "、")
        Save-State
        $public = Public-State
        $public.device = @{ code = $code }
        Send-Json $context $public
        continue
      }

      if ($path -eq "/api/posts" -and $method -eq "POST") {
        $clientId = [string]$body.clientId
        $boardId = [string]$body.boardId
        $name = ([string]$body.name).Trim()
        $text = ([string]$body.text).Trim()
        if (@("square", "night", "work") -notcontains $boardId) {
          Send-Json $context @{ error = "没有这个版块。" } 400
          continue
        }
        if (-not $State.names.ContainsKey($name) -or $State.names[$name] -ne $clientId) {
          Send-Json $context @{ error = "请先用这个名字进入。" } 403
          continue
        }
        if ($text.Length -gt 200) { $text = $text.Substring(0, 200) }
        $images = New-Object System.Collections.Generic.List[object]
        foreach ($image in @($body.images)) {
          if ($null -eq $image -or [string]::IsNullOrWhiteSpace([string]$image)) { continue }
          if ($images.Count -ge 4) { break }
          [void]$images.Add([string]$image)
        }
        if (-not $text -and $images.Count -eq 0) {
          Send-Json $context @{ error = "写一点字，或配上一张图。" } 400
          continue
        }
        $slot = 0
        if ([int]$body.alias -eq 1) { $slot = 1 }
        $post = @{
          id = [guid]::NewGuid().ToString("N")
          clientId = $clientId
          alias = $slot
          name = $name
          avatar = [string]$body.avatar
          text = $text
          images = $images
          time = "今天 " + (Get-Date -Format "HH:mm")
          likedBy = (New-Object System.Collections.Generic.List[object])
          replies = (New-Object System.Collections.Generic.List[object])
        }
        $State.posts[$boardId].Insert(0, $post)
        Add-History $clientId "发言" $(if ($text) { $text } else { "图片" })
        Save-State
        Send-Json $context (Public-State)
        continue
      }

      if ($path -eq "/api/replies" -and $method -eq "POST") {
        $clientId = [string]$body.clientId
        $name = ([string]$body.name).Trim()
        $text = ([string]$body.text).Trim()
        if (-not $State.names.ContainsKey($name) -or $State.names[$name] -ne $clientId) {
          Send-Json $context @{ error = "请先用这个名字进入。" } 403
          continue
        }
        if (-not $text) {
          Send-Json $context @{ error = "先写一句回应。" } 400
          continue
        }
        if ($text.Length -gt 80) { $text = $text.Substring(0, 80) }
        $post = Find-Post ([string]$body.boardId) ([string]$body.postId)
        if (-not $post) {
          Send-Json $context @{ error = "这条发言已经不在了。" } 404
          continue
        }
        $slot = 0
        if ([int]$body.alias -eq 1) { $slot = 1 }
        Add-History $clientId "回应" $text
        [void]$post.replies.Add(@{
          clientId = $clientId
          alias = $slot
          name = $name
          avatar = [string]$body.avatar
          text = $text
        })
        Save-State
        Send-Json $context (Public-State)
        continue
      }

      if ($path -eq "/api/likes" -and $method -eq "POST") {
        $clientId = [string]$body.clientId
        $post = Find-Post ([string]$body.boardId) ([string]$body.postId)
        if (-not $post) {
          Send-Json $context @{ error = "这条发言已经不在了。" } 404
          continue
        }
        $liked = Ensure-List $post.likedBy
        $post.likedBy = $liked
        $existing = $null
        foreach ($item in $liked) { if ([string]$item -eq $clientId) { $existing = $item; break } }
        if ($null -ne $existing) { [void]$liked.Remove($existing) } else { [void]$liked.Add($clientId) }
        Add-History $clientId "喜欢" $(if ($post.text) { [string]$post.text } else { "一条发言" })
        Save-State
        Send-Json $context (Public-State)
        continue
      }

      Send-Json $context @{ error = "没有这个接口。" } 404
      continue
    }

    $relative = $path
    if ($relative -eq "/") { $relative = "/index.html" }
    $name = [System.IO.Path]::GetFileName($relative)
    $file = Join-Path $Root $name
    if ((Test-Path -LiteralPath $file) -and $name -match '^(index\.html|styles\.css|app\.js)$') {
      $bytes = [System.IO.File]::ReadAllBytes($file)
      $ext = [System.IO.Path]::GetExtension($file).ToLower()
      Write-Http 200 $types[$ext] $bytes
    } else {
      Write-Http 404 "text/plain; charset=utf-8" ([System.Text.Encoding]::UTF8.GetBytes("not found"))
    }
  } catch {
    try { Send-Json $null @{ error = "没有完成，请再试一次。" } 500 } catch {}
  } finally {
    try { $client.Close() } catch {}
  }
}
