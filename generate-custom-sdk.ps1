#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generates a custom Microsoft Graph Beta SDK with only the required API endpoints using Kiota.

.DESCRIPTION
    This script creates a minimal Microsoft Graph Beta SDK containing only:
    - RoleManagement.Directory.RoleAssignmentApprovals API
    - IdentityGovernance.PrivilegedAccess.Group.AssignmentApprovals API

    The generated SDK is a drop-in replacement for Microsoft.Graph.Beta with significantly reduced size.

.PARAMETER Clean
    If specified, cleans the output directory before generation.

.PARAMETER SkipBuild
    If specified, skips building the project after generation.

.EXAMPLE
    .\generate-custom-sdk.ps1

.EXAMPLE
    .\generate-custom-sdk.ps1 -Clean -SkipBuild
#>

[CmdletBinding()]
param(
    [switch]$Clean,
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

# Configuration
$OpenApiUrl = "https://aka.ms/graph/beta/openapi.yaml"
$OutputPath = "./custom-sdk/Devolutions.Graph.Beta"
$ClassName = "GraphServiceClient"
$NamespaceName = "Devolutions.Graph.Beta"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Custom Microsoft Graph Beta SDK Generator" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if Kiota is installed
Write-Host "[1/6] Checking Kiota installation..." -ForegroundColor Yellow
try {
    $kiotaVersion = kiota --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ Kiota is installed: $kiotaVersion" -ForegroundColor Green
    }
} catch {
    Write-Host "  ✗ Kiota not found. Installing..." -ForegroundColor Red
    Write-Host ""
    dotnet tool install --global Microsoft.OpenApi.Kiota
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to install Kiota. Please install manually: dotnet tool install --global Microsoft.OpenApi.Kiota"
        exit 1
    }
    Write-Host "  ✓ Kiota installed successfully" -ForegroundColor Green
}
Write-Host ""

# Step 2: Clean output directory if requested
if ($Clean) {
    Write-Host "[2/6] Cleaning output directory..." -ForegroundColor Yellow
    if (Test-Path $OutputPath) {
        Remove-Item -Path $OutputPath -Recurse -Force
        Write-Host "  ✓ Cleaned: $OutputPath" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Nothing to clean" -ForegroundColor Green
    }
} else {
    Write-Host "[2/6] Skipping clean (use -Clean to clean output directory)" -ForegroundColor Yellow
}
Write-Host ""

# Step 3: Create output directory
Write-Host "[3/6] Creating output directory..." -ForegroundColor Yellow
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
Write-Host "  ✓ Directory ready: $OutputPath" -ForegroundColor Green
Write-Host ""

# Step 4: Generate SDK with Kiota
Write-Host "[4/6] Generating custom SDK with Kiota..." -ForegroundColor Yellow
Write-Host "  OpenAPI spec: $OpenApiUrl" -ForegroundColor Gray
Write-Host "  Include paths:" -ForegroundColor Gray
Write-Host "    - /roleManagement/directory/roleAssignmentApprovals/**" -ForegroundColor Gray
Write-Host "    - /identityGovernance/privilegedAccess/group/assignmentApprovals/**" -ForegroundColor Gray
Write-Host ""
Write-Host "  This may take a few minutes..." -ForegroundColor Gray
Write-Host ""

$kiotaArgs = @(
    "generate",
    "--openapi", $OpenApiUrl,
    "--include-path", "/roleManagement/directory/roleAssignmentApprovals/**",
    "--include-path", "/identityGovernance/privilegedAccess/group/assignmentApprovals/**",
    "--language", "CSharp",
    "--class-name", $ClassName,
    "--namespace-name", $NamespaceName,
    "--output", $OutputPath,
    "--backing-store",
    "--exclude-backward-compatible"
)

& kiota @kiotaArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Kiota generation failed. Please check the error messages above."
    exit 1
}

Write-Host ""
Write-Host "  ✓ SDK generated successfully" -ForegroundColor Green
Write-Host ""

# Step 5: Create project file
Write-Host "[5/6] Creating project file..." -ForegroundColor Yellow

$projectFileContent = @"
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <Description>Custom minimal Microsoft Graph Beta client library targeting specific approval endpoints.</Description>
    <Copyright>© Devolutions. All rights reserved.</Copyright>
    <AssemblyTitle>Devolutions Graph Beta Client Library</AssemblyTitle>
    <Authors>Devolutions</Authors>
    <TargetFramework>net8.0</TargetFramework>
    <LangVersion>latest</LangVersion>
    <AssemblyName>Devolutions.Graph.Beta</AssemblyName>
    <PackageId>Devolutions.Graph.Beta</PackageId>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    <SignAssembly>false</SignAssembly>
    <Version>1.0.0-custom</Version>
    <NoWarn>`$(NoWarn);1701;1702;1705;1591</NoWarn>
  </PropertyGroup>

  <PropertyGroup Condition="`$([MSBuild]::IsTargetFrameworkCompatible('`$(TargetFramework)','net6.0'))">
    <IsTrimmable>true</IsTrimmable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.Graph.Core" Version="3.*" />
    <PackageReference Include="Microsoft.Kiota.Abstractions" Version="[1.17.1,2.0.0)" />
    <PackageReference Include="Microsoft.Kiota.Http.HttpClientLibrary" Version="[1.17.1,2.0.0)" />
    <PackageReference Include="Microsoft.Kiota.Serialization.Form" Version="[1.17.1,2.0.0)" />
    <PackageReference Include="Microsoft.Kiota.Serialization.Json" Version="[1.17.1,2.0.0)" />
    <PackageReference Include="Microsoft.Kiota.Serialization.Text" Version="[1.17.1,2.0.0)" />
    <PackageReference Include="Microsoft.Kiota.Serialization.Multipart" Version="[1.17.1,2.0.0)" />
  </ItemGroup>
</Project>
"@

$projectFilePath = Join-Path $OutputPath "Devolutions.Graph.Beta.csproj"
Set-Content -Path $projectFilePath -Value $projectFileContent -Encoding UTF8
Write-Host "  ✓ Project file created: $projectFilePath" -ForegroundColor Green

# Create GraphServiceClient Extensions for compatibility
$extensionsFileContent = @"
// ------------------------------------------------------------------------------
//  Custom extensions to add Devolutions.Graph.Beta SDK compatibility constructors
// ------------------------------------------------------------------------------

namespace Devolutions.Graph.Beta
{
    using System;
    using System.Net.Http;
    using System.Reflection;
    using Microsoft.Graph;
    using Microsoft.Graph.Core.Requests;
    using Microsoft.Kiota.Abstractions.Authentication;
    using Microsoft.Kiota.Abstractions;

    /// <summary>
    /// Extension to GraphServiceClient adding compatibility constructors from original Microsoft.Graph.Beta SDK
    /// </summary>
    public partial class GraphServiceClient : IDisposable
    {
        private static readonly Version assemblyVersion = typeof(GraphServiceClient).GetTypeInfo().Assembly.GetName().Version;
        private static readonly GraphClientOptions graphClientOptions = new GraphClientOptions
        {
            GraphServiceLibraryClientVersion = `$"{assemblyVersion.Major}.{assemblyVersion.Minor}.{assemblyVersion.Build}",
            GraphServiceTargetVersion = "beta",
        };

        /// <summary>
        /// Constructs a new <see cref="GraphServiceClient"/>.
        /// </summary>
        /// <param name="authenticationProvider">The <see cref="IAuthenticationProvider"/> for authenticating request messages.</param>
        /// <param name="baseUrl">The base service URL. For example, "https://graph.microsoft.com/beta"</param>
        public GraphServiceClient(
            IAuthenticationProvider authenticationProvider,
            string baseUrl = null
            ) : this(new BaseGraphRequestAdapter(authenticationProvider, graphClientOptions, httpClient: GraphClientFactory.Create(graphClientOptions, "beta")))
        {
            if (!string.IsNullOrEmpty(baseUrl))
            {
                RequestAdapter.BaseUrl = baseUrl;
            }
        }

        /// <summary>
        /// Constructs a new <see cref="GraphServiceClient"/>.
        /// </summary>
        /// <param name="httpClient">The customized <see cref="HttpClient"/> to be used for making requests</param>
        /// <param name="authenticationProvider">The <see cref="IAuthenticationProvider"/> for authenticating request messages.
        /// Defaults to <see cref="AnonymousAuthenticationProvider"/> so that authentication is handled by custom middleware in the httpClient</param>
        /// <param name="baseUrl">The base service URL. For example, "https://graph.microsoft.com/beta"</param>
        public GraphServiceClient(
            HttpClient httpClient,
            IAuthenticationProvider authenticationProvider = null,
            string baseUrl = null) : this(new BaseGraphRequestAdapter(authenticationProvider ?? new AnonymousAuthenticationProvider(), graphClientOptions, httpClient: httpClient))
        {
            if (!string.IsNullOrEmpty(baseUrl))
            {
                RequestAdapter.BaseUrl = baseUrl;
            }
        }

        /// <summary>
        /// Cleanup anything as needed
        /// </summary>
        public void Dispose()
        {
            if (this.RequestAdapter is IDisposable disposable)
            {
                disposable.Dispose();
            }
        }
    }
}
"@

$extensionsFilePath = Join-Path $OutputPath "GraphServiceClient.Extensions.cs"
Set-Content -Path $extensionsFilePath -Value $extensionsFileContent -Encoding UTF8
Write-Host "  ✓ Extensions file created: $extensionsFilePath" -ForegroundColor Green
Write-Host ""

# Step 6: Build the SDK
if ($SkipBuild) {
    Write-Host "[6/6] Skipping build (use without -SkipBuild to build)" -ForegroundColor Yellow
} else {
    Write-Host "[6/6] Building the SDK..." -ForegroundColor Yellow
    Write-Host ""

    dotnet build $projectFilePath --configuration Release

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Build failed. Please check the error messages above."
        exit 1
    }

    Write-Host ""
    Write-Host "  ✓ Build completed successfully" -ForegroundColor Green
    Write-Host ""

    # Display build output information
    Write-Host "Build Output Locations:" -ForegroundColor Cyan
    $releaseDir = Join-Path $OutputPath "bin\Release"
    if (Test-Path $releaseDir) {
        Get-ChildItem -Path $releaseDir -Recurse -Include "Devolutions.Graph.Beta.dll" | ForEach-Object {
            $sizeKB = [math]::Round($_.Length / 1KB, 2)
            $sizeMB = [math]::Round($_.Length / 1MB, 2)
            Write-Host "  📦 $($_.FullName)" -ForegroundColor White
            Write-Host "     Size: $sizeKB KB ($sizeMB MB)" -ForegroundColor Gray
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "✓ Generation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review generated code in: $OutputPath" -ForegroundColor White
Write-Host "  2. Test the custom DLL as a drop-in replacement" -ForegroundColor White
Write-Host "  3. Compare DLL sizes with the original Microsoft.Graph.Beta" -ForegroundColor White
Write-Host ""
