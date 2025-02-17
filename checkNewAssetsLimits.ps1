$token = "apiToken-changeMe"
$userName = "email-changeMe"
# Set your API details
$jiraBaseUrl = "https://changeMe.atlassian.net"
# Set headers for authentication
$headers = @{
    "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$userName`:$token"))
    "Accept"        = "application/json"
}

$url = "$jiraBaseUrl/rest/servicedeskapi/assets/workspace"
$response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get

$assetsBaseUrl = "https://api.atlassian.com/jsm/assets/workspace/$($response.values.workspaceId)/v1"

$url = "$assetsBaseUrl/objectschema/list"
$response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
$schemas = $response.values

foreach($schema in $schemas){
    if($schema.name -ne "Services"){
        $url = "$assetsBaseUrl/objectschema/$($schema.id)/objecttypes"
        $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
        $schema | Add-Member -MemberType NoteProperty -Name "objectTypes" -Value $response
        foreach($objectType in $schema.objectTypes){
            $url = "$assetsBaseUrl/objecttype/$($objectType.id)/attributes"
            $response = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
            $objectType | Add-Member -MemberType NoteProperty -Name "attributes" -Value $response
            $objectType | Add-Member -MemberType NoteProperty -Name "schema" -Value $schema
            foreach($attribute in $objectType.Attributes){
                $attribute | Add-Member -MemberType NoteProperty -Name "objectType" -Value $objectType -Force
            }            
        }
    }    
}


Write-Host "Discovered Assets structure"
foreach($schema in $schemas){
    if($schema.name -ne "Services"){
        Write-Host "$($schema.name)"
        foreach($objectType in $schema.objectTypes){      
            Write-Host "`t$($objectType.name)"
            foreach($attribute in $objectType.Attributes){            
                Write-Host "`t`t$($attribute.name)"                  
            }        
        }
    }    
}

$objectTypesWithMoreThan2UniqueAttributes = @()
$objectTypesWithMoreThan120Attributes = @()
$attributeWithMoreThan50CardinalityOnURLEmailandSelect = @()
$attributeWithMoreThan2700Options = @()

foreach($schema in $schemas){   
    foreach($objectType in $schema.objectTypes){
        $uniqueAttr = 0      
        foreach($attribute in $objectType.Attributes){
             if($attribute.uniqueAttribute){
                 $uniqueAttr++
             }
             if($attribute.defaultType.id -eq "7" -or $attribute.defaultType.id -eq "8" -or $attribute.defaultType.id -eq "10"){
                if($attribute.maximumCardinality -gt 50){
                    $attributeWithMoreThan50CardinalityOnURLEmailandSelect += $attribute
                }               
            }
            if($attribute.options.Length -gt 2700){
                $attributeWithMoreThan2700Options += $attribute
            }
        }
        if($uniqueAttr -gt 2){
            $objectTypesWithMoreThan2UniqueAttributes += $objectType
        }
        if($objectType.Attributes.Count -gt 120){
            $objectTypesWithMoreThan120Attributes += $objectType
        }       
    }
}

Write-Host "`n`n`n-------------------------------------------------"
Write-Host "Results of new limits check`n`n"

Write-Host "Object Types with more than 2 unique attributes"
foreach($objectType in $objectTypesWithMoreThan2UniqueAttributes){
    Write-Host "`tObject Type: $($objectType.name)"
     Write-Host "`t`Unique attributes:"
    foreach($attribute in $objectType.Attributes){       
        if($attribute.uniqueAttribute){
            Write-Host "`t`t`t- $($attribute.name)"
        }                  
    }        
}
if($objectTypesWithMoreThan2UniqueAttributes.Count -eq 0){
    Write-Host "`tNo object type with more than 2 unique attributes"
}
Write-Host "-------------------------------------------------`n"

Write-Host "Object Types with more than 120 attributes"
foreach($objectType in $objectTypesWithMoreThan120Attributes){
    Write-Host "`tObject Type: $($objectType.name)"           
}
if($objectTypesWithMoreThan120Attributes.Count -eq 0){
    Write-Host "`tNo object type with more than 120 attributes"
}
Write-Host "-------------------------------------------------`n"

Write-Host "Attributes with more than 50 cardinality on URL, Email and Select"
foreach($attribute in $attributeWithMoreThan50CardinalityOnURLEmailandSelect){
    Write-Host "`tAttribute: $($attribute.name)"
    Write-Host "`t`t`Object Type:$($attribute.objectType.name)"
    Write-Host "`t`t`t`Schema:$($attribute.objectType.schema.name)"
}
if($attributeWithMoreThan50CardinalityOnURLEmailandSelect.Count -eq 0){
    Write-Host "`tNo attribute with more than 50 cardinality on URL, Email and Select"
}

Write-Host "-------------------------------------------------`n"
write-Host "Attributes with more than 2700 options"
foreach($attribute in $attributeWithMoreThan2700Options){
    Write-Host "`tAttribute: $($attribute.name)"
    Write-Host "`t`t`Object Type:$($attribute.objectType.name)"
    Write-Host "`t`t`t`Schema:$($attribute.objectType.schema.name)"
}
if($attributeWithMoreThan2700Options.Count -eq 0){
    Write-Host "`tNo attribute with more than 2700 options"
}
Write-Host "-------------------------------------------------`n"
