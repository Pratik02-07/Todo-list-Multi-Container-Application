
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^sha-[a-f0-9]{40}$')]
    [string]$ImageTag
)

$ErrorActionPreference = "Stop"

# Configuration
$ExpectedContext = "kind-todo-lab"
$Namespace = "todo-app"

$BackendDeployment = "backend"
$FrontendDeployment = "frontend"

$BackendImage = "pratik0207/todolist-backend:$ImageTag"
$FrontendImage = "pratik0207/todolist-frontend:$ImageTag"

$HealthUrl = "http://localhost:8080/health"
$ReadyUrl = "http://localhost:8080/ready"

# Original images for rollback
$OriginalBackendImage = $null
$OriginalFrontendImage = $null

# Deployment tracking
$BackendUpdateStarted = $false
$FrontendUpdateStarted = $false

$BackendRolloutSucceeded = $false
$FrontendRolloutSucceeded = $false

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

try {
    # 1. Verify Docker Hub images
    Write-Step "Verifying Docker Hub images"

    docker manifest inspect $BackendImage | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Backend image not found: $BackendImage"
    }

    Write-Success "Backend image is available"

    docker manifest inspect $FrontendImage | Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Frontend image not found: $FrontendImage"
    }

    Write-Success "Frontend image is available"

    # 2. Verify Kubernetes context
    Write-Step "Checking Kubernetes context"

    $CurrentContext = kubectl config current-context

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to determine Kubernetes context"
    }

    if ($CurrentContext -ne $ExpectedContext) {
        throw "Wrong Kubernetes context: $CurrentContext. Expected: $ExpectedContext"
    }

    Write-Success "Connected to $ExpectedContext"

    # 3. Verify cluster connectivity and namespace
Write-Step "Checking Kubernetes cluster"

kubectl cluster-info | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Unable to connect to Kubernetes cluster"
}

Write-Success "Kubernetes cluster is reachable"

kubectl get namespace $Namespace | Out-Null

if ($LASTEXITCODE -ne 0) {
    throw "Namespace $Namespace does not exist"
}

Write-Success "Namespace $Namespace exists"

    # 4. Capture current deployment images
    Write-Step "Capturing current deployment images"

    $OriginalBackendImage = kubectl get deployment $BackendDeployment `
    -n $Namespace `
    -o 'jsonpath={.spec.template.spec.containers[0].image}'

if ($LASTEXITCODE -ne 0) {
    throw "Could not retrieve current backend image"
}

    $OriginalFrontendImage = kubectl get deployment $FrontendDeployment `
    -n $Namespace `
    -o 'jsonpath={.spec.template.spec.containers[0].image}'

if ($LASTEXITCODE -ne 0) {
    throw "Could not retrieve current frontend image"
}

    if (-not $OriginalBackendImage -or -not $OriginalFrontendImage) {
        throw "Could not identify current deployment images"
    }

    Write-Host "Backend:  $OriginalBackendImage"
    Write-Host "Frontend: $OriginalFrontendImage"

    # 5. Update backend

if ($OriginalBackendImage -eq $BackendImage) {
    Write-Success "Backend already uses the requested image. Skipping update."
    $BackendRolloutSucceeded = $true
}
else {
    Write-Step "Updating backend image"

    kubectl set image deployment/$BackendDeployment `
        backend=$BackendImage `
        -n $Namespace

    if ($LASTEXITCODE -ne 0) {
        throw "Backend image update failed"
    }

    $BackendUpdateStarted = $true

    kubectl rollout status deployment/$BackendDeployment `
        -n $Namespace `
        --timeout=180s

    if ($LASTEXITCODE -ne 0) {
        throw "Backend rollout failed"
    }

    $BackendRolloutSucceeded = $true

    Write-Success "Backend rollout completed"
}

    # 6. Update frontend

if ($OriginalFrontendImage -eq $FrontendImage) {
    Write-Success "Frontend already uses the requested image. Skipping update."
    $FrontendRolloutSucceeded = $true
}
else {
    Write-Step "Updating frontend image"

    kubectl set image deployment/$FrontendDeployment `
        frontend=$FrontendImage `
        -n $Namespace

    if ($LASTEXITCODE -ne 0) {
        throw "Frontend image update failed"
    }

    $FrontendUpdateStarted = $true

    kubectl rollout status deployment/$FrontendDeployment `
        -n $Namespace `
        --timeout=180s

    if ($LASTEXITCODE -ne 0) {
        throw "Frontend rollout failed"
    }

    $FrontendRolloutSucceeded = $true

    Write-Success "Frontend rollout completed"
}

    # 7. Verify application health with retries
Write-Step "Checking application health"

$MaxHealthAttempts = 6
$HealthCheckSucceeded = $false

for ($Attempt = 1; $Attempt -le $MaxHealthAttempts; $Attempt++) {
    try {
        Write-Host "Health check attempt $Attempt/$MaxHealthAttempts"

        $Health = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 10
        $Ready = Invoke-RestMethod -Uri $ReadyUrl -TimeoutSec 10

        if (
            $Health.status -eq "alive" -and
            $Ready.status -eq "ready" -and
            $Ready.database -eq "connected"
        ) {
            $HealthCheckSucceeded = $true
            break
        }
    }
    catch {
        Write-Host "Application is not ready yet." -ForegroundColor Yellow
    }

    if ($Attempt -lt $MaxHealthAttempts) {
        Start-Sleep -Seconds 5
    }
}

if (-not $HealthCheckSucceeded) {
    throw "Application health checks failed after $MaxHealthAttempts attempts"
}

Write-Success "Application is healthy"
Write-Success "MongoDB connection is ready"

    # 8. Final deployment summary
    Write-Step "Deployment summary"

    kubectl get deployments -n $Namespace

    if ($LASTEXITCODE -ne 0) {
        throw "Could not retrieve deployment summary"
    }

    Write-Host "`nBackend image:  $BackendImage"
    Write-Host "Frontend image: $FrontendImage"

    Write-Success "Kind deployment completed successfully"
}
catch {
    Write-Host "`n[ERROR] $($_.Exception.Message)" -ForegroundColor Red

    # 9. Safe component-specific rollback
    $RollbackBackend = $false
    $RollbackFrontend = $false

    # Roll back all components whose images were changed.
# Keep both application components on the original release.

$RollbackBackend = (
    $BackendUpdateStarted -or $BackendRolloutSucceeded
) -and (
    $OriginalBackendImage -ne $BackendImage
)

$RollbackFrontend = (
    $FrontendUpdateStarted -or $FrontendRolloutSucceeded
) -and (
    $OriginalFrontendImage -ne $FrontendImage
)

    if ($RollbackBackend -or $RollbackFrontend) {
        Write-Host "`nStarting targeted rollback..." -ForegroundColor Yellow

        if ($RollbackBackend) {
            try {
                Write-Step "Rolling back backend"

                kubectl set image deployment/$BackendDeployment `
                    backend=$OriginalBackendImage `
                    -n $Namespace

                if ($LASTEXITCODE -ne 0) {
                    throw "Backend rollback image update failed"
                }

                kubectl rollout status deployment/$BackendDeployment `
                    -n $Namespace `
                    --timeout=180s

                if ($LASTEXITCODE -ne 0) {
                    throw "Backend rollback rollout failed"
                }

                Write-Success "Backend rollback completed"
            }
            catch {
                Write-Host "[ROLLBACK ERROR] $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        if ($RollbackFrontend) {
            try {
                Write-Step "Rolling back frontend"

                kubectl set image deployment/$FrontendDeployment `
                    frontend=$OriginalFrontendImage `
                    -n $Namespace

                if ($LASTEXITCODE -ne 0) {
                    throw "Frontend rollback image update failed"
                }

                kubectl rollout status deployment/$FrontendDeployment `
                    -n $Namespace `
                    --timeout=180s

                if ($LASTEXITCODE -ne 0) {
                    throw "Frontend rollback rollout failed"
                }

                Write-Success "Frontend rollback completed"
            }
            catch {
                Write-Host "[ROLLBACK ERROR] $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host "No deployment rollback was required." -ForegroundColor Yellow
    }

    Write-Host "`nCheck Kubernetes deployment status before retrying." -ForegroundColor Yellow
    # Verify application health after rollback
if ($RollbackBackend -or $RollbackFrontend) {
    Write-Step "Verifying application health after rollback"

    $RollbackHealthSucceeded = $false

    for ($Attempt = 1; $Attempt -le 6; $Attempt++) {
        try {
            Write-Host "Rollback health check $Attempt/6"

            $Health = Invoke-RestMethod -Uri $HealthUrl -TimeoutSec 10
            $Ready = Invoke-RestMethod -Uri $ReadyUrl -TimeoutSec 10

            if (
                $Health.status -eq "alive" -and
                $Ready.status -eq "ready" -and
                $Ready.database -eq "connected"
            ) {
                $RollbackHealthSucceeded = $true
                break
            }
        }
        catch {
            Write-Host "Application is not healthy yet." -ForegroundColor Yellow
        }

        if ($Attempt -lt 6) {
            Start-Sleep -Seconds 5
        }
    }

    if ($RollbackHealthSucceeded) {
        Write-Success "Application recovered successfully after rollback"
    }
    else {
        Write-Host "[CRITICAL] Application health check failed after rollback." -ForegroundColor Red
    }
}

    exit 1
}
