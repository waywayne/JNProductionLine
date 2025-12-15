# Gitee Go Pipeline Configuration

## Available Configuration Files

### 1. gitee-go.yml (Recommended)
**Status**: ✅ Ready to use
**Features**:
- Version: 1.0
- Two stages: PrepareEnvironment, BuildApplication
- Complete build pipeline
- No Chinese characters or spaces in field names

**Structure**:
```
stages:
  - PrepareEnvironment
    - CheckEnvironment job
  - BuildApplication
    - BuildWindows job
```

### 2. build-windows.yml (Alternative)
**Status**: ✅ Ready to use
**Features**:
- Version: 1.0
- Single stage: BuildStage
- Simplified structure

### 3. pipeline.yml (PowerShell based)
**Status**: ✅ Ready to use
**Features**:
- Version: 1.0
- Two stages: prepare, build
- Uses PowerShell tasks

## Key Configuration Elements

All files now include:
- ✅ `version: 1.0` field
- ✅ `stages` structure with proper hierarchy
- ✅ No Chinese characters
- ✅ No spaces in field names (CamelCase)
- ✅ Proper pool configuration
- ✅ Job dependencies

## Usage

1. Choose one configuration file
2. In Gitee Go settings, select the file
3. Trigger build by pushing to master/main branch

## Troubleshooting

If pipeline still fails:
1. Check Gitee Go logs for specific errors
2. Verify Windows build environment is available
3. Ensure all field names match Gitee Go requirements
4. Contact Gitee support with error details
