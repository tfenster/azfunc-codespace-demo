using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

# Write to the Azure Functions log stream.
Write-Host "PowerShell HTTP trigger function processed a request."

# Interact with query parameters or the body of the request.
$vmname = $Request.Query.VmName

if ($vmname) {
    try {
        Write-Host "Getting access token and connecting to Azure account"
        $accessToken = ""
        $clientId = ""
        if (Test-Path env:\accesstoken) {
            $accessToken = $env:accesstoken
            $clientId = $env:clientid
        }
        else {
            $resourceURI = "https://management.core.windows.net/"
            $tokenAuthURI = $env:IDENTITY_ENDPOINT + "?resource=$resourceURI&api-version=2019-08-01"
            $tokenResponse = Invoke-RestMethod -Method Get -Headers @{"X-IDENTITY-HEADER" = "$env:IDENTITY_HEADER" } -Uri $tokenAuthURI
            $accessToken = $tokenResponse.access_token
            $clientId = $tokenResponse.client_id
        }

        Connect-AzAccount -AccessToken $accessToken -AccountId $clientId | Out-Null
        $body = Get-AzVM -VMName "$vmname" -Status | Select-Object powerstate, id, vmid, name

        if ($null -eq $body) {
            Write-Host "no response"
            Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::NotFound
                })
        }
        else {
            Write-Host "Success"
            Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                    StatusCode = [HttpStatusCode]::OK
                    Body       = $body
                })  
        } 
    }
    catch {
        Write-Host "Caught an exception: $($_.ToString())"
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::BadRequest
                Body       = @{
                    "Message"    = $_.ToString()
                    "StackTrace" = $_.ScriptStackTrace
                }
            })
    } 
}
else {
    Write-Host "Didn't find the expected param"
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::BadRequest
            Body       = "This HTTP triggered function executed successfully. Pass a VM name in the query string to get the PowerState."
        })    
}
