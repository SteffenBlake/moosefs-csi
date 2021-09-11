$REPO = "steffenblake/moosefs-csi-plugin"
$VER = "1.0.1"
$VERBOSE = $true

$OSLIST = "linux"
$ARCHLIST = @{
    # arm = "arm/v7"; TODO: Add ARMv7 support (Need special logic in docker file for moosefs apt-get to use raspbian image)
    arm64 = "arm64"; 
    amd64 = "amd64" 
}

if (Test-Path -Path ./cmd/moosefs-csi-plugin/bin) {
    Write-Output "Cleaning up folders..."
    Remove-Item ./cmd/moosefs-csi-plugin/bin -Recurse -Force
}

$ManifestLatest = $Repo + ":latest"
$ManifestVer = $Repo + ":" + $VER

Write-Output "Composing Go Environment..."
$Env:CGO_ENABLED=0

ForEach ($OS in $OSLIST) {
    $Env:GOOS=$OS
    ForEach ($ARCH in $ARCHLIST.keys) {
        $Env:GOARCH=$ARCH
        $CompilePath = "./cmd/moosefs-csi-plugin/bin/$OS/" + $ARCHLIST[$Arch] + "/moosefs-csi-plugin"
        Write-Output "Compiling $OS/$ARCH >>> $CompilePath"
        if ($VERBOSE) {
            Write-Output "Sanity Check Go Env..."
            Write-Output (go env)
        }
        go build -a -o $CompilePath ./cmd/moosefs-csi-plugin/main.go

        $ArchRepo = $Repo + ":" + $OS + "-" + $ARCH
        $LatestRepo = $ArchRepo + "-latest"
        $VerRepo = $ArchRepo + "-" + $VER
        Write-Output "Pushing to $LatestRepo / $VerRepo"
        docker buildx build ./cmd/moosefs-csi-plugin --platform $OS/$ARCH -t $LatestRepo -t $VerRepo --push

        Write-Output "Composing to Manifests $ManifestLatest / $ManifestVer"
        docker manifest create $ManifestLatest --amend $LatestRepo
        docker manifest create $ManifestVer --amend $VerRepo
    }
}

Write-Output "Publishing to Manifests $ManifestLatest / $ManifestVer"

docker manifest push $ManifestLatest
docker manifest push $ManifestVer