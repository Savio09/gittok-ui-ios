#!/usr/bin/env python3
"""Generate the checked-in Xcode project using only Python's standard library."""
from pathlib import Path
import hashlib
import json
ROOT = Path(__file__).resolve().parents[1]
objects = {}
def ident(key): return hashlib.sha256(key.encode()).hexdigest()[:24].upper()
def put(key, value):
    objects[ident(key)] = value
    return ident(key)
def q(value): return json.dumps(str(value))
def refs(values): return '(' + ', '.join(values) + ')'
def obj(**kwargs): return '{ ' + ' '.join(f'{k} = {v};' for k,v in kwargs.items()) + ' }'
def file(path, filetype): return put('file:'+path, obj(isa='PBXFileReference', lastKnownFileType=filetype, path=q(path), sourceTree=q('SOURCE_ROOT')))
app_files = sorted(str(p.relative_to(ROOT)) for p in (ROOT/'GitTok').glob('*.swift'))
unit_files = sorted(str(p.relative_to(ROOT)) for p in (ROOT/'Tests/GitTokCoreTests').glob('*.swift'))
ui_files = sorted(str(p.relative_to(ROOT)) for p in (ROOT/'GitTokUITests').glob('*.swift'))
local_package = put('package', obj(isa='XCLocalSwiftPackageReference', relativePath=q('.')))
product = put('core-product', obj(isa='XCSwiftPackageProductDependency', package=local_package, productName='GitTokCore'))
products = []
def target(name, files, producttype, extension, settings, package=False, deps=[]):
    product_ref = put('product:'+name, obj(isa='PBXFileReference', explicitFileType=q('wrapper.application' if extension=='app' else 'wrapper.cfbundle'), includeInIndex='0', path=q(name+'.'+extension), sourceTree='BUILT_PRODUCTS_DIR'))
    products.append(product_ref)
    source_refs=[]
    for path in files:
        f=file(path,'sourcecode.swift')
        source_refs.append(put('build:'+name+path, obj(isa='PBXBuildFile', fileRef=f)))
    sources=put('sources:'+name, obj(isa='PBXSourcesBuildPhase', buildActionMask='2147483647', files=refs(source_refs), runOnlyForDeploymentPostprocessing='0'))
    frameworks=[]
    if package: frameworks=[put('framework:'+name, obj(isa='PBXBuildFile', productRef=product))]
    frameworks=put('frameworks:'+name, obj(isa='PBXFrameworksBuildPhase', buildActionMask='2147483647',files=refs(frameworks),runOnlyForDeploymentPostprocessing='0'))
    resource_refs=[]
    if name=='GitTokCoreTests':
        f=file('Tests/GitTokCoreTests/Fixtures','folder')
        resource_refs=[put('fixture-build',obj(isa='PBXBuildFile',fileRef=f))]
    resources=put('resources:'+name,obj(isa='PBXResourcesBuildPhase',buildActionMask='2147483647',files=refs(resource_refs),runOnlyForDeploymentPostprocessing='0'))
    configs=[]
    for config in ['Debug','Release']:
        configs.append(put('config:'+name+config,obj(isa='XCBuildConfiguration',name=q(config),buildSettings=obj(**dict(settings, ONLY_ACTIVE_ARCH='YES' if config=='Debug' else 'NO')))))
    configlist=put('configs:'+name,obj(isa='XCConfigurationList',buildConfigurations=refs(configs),defaultConfigurationIsVisible='0',defaultConfigurationName='Release'))
    return put('target:'+name,obj(isa='PBXNativeTarget',buildConfigurationList=configlist,buildPhases=refs([sources,frameworks,resources]),buildRules='()',dependencies=refs(deps),name=q(name),packageProductDependencies=refs([product] if package else []),productName=q(name),productReference=product_ref,productType=q(producttype)))
common=dict(SWIFT_VERSION='6.0',IPHONEOS_DEPLOYMENT_TARGET='18.0',SDKROOT='iphoneos',SUPPORTED_PLATFORMS=q('iphoneos iphonesimulator'),TARGETED_DEVICE_FAMILY=q('1,2'),CODE_SIGN_STYLE='Automatic',SWIFT_STRICT_CONCURRENCY='complete')
app=target('GitTok',app_files,'com.apple.product-type.application','app',dict(**common,PRODUCT_BUNDLE_IDENTIFIER='dev.gittok.ios',PRODUCT_NAME=q('$(TARGET_NAME)'),INFOPLIST_FILE=q('GitTok/Info.plist'),GENERATE_INFOPLIST_FILE='NO',MARKETING_VERSION='0.1.0',CURRENT_PROJECT_VERSION='1',SWIFT_EMIT_LOC_STRINGS='YES'),True)
proxy=put('proxy',obj(isa='PBXContainerItemProxy',containerPortal=ident('project'),proxyType='1',remoteGlobalIDString=app,remoteInfo='GitTok'))
dependency=put('app-dependency',obj(isa='PBXTargetDependency',target=app,targetProxy=proxy))
unit=target('GitTokCoreTests',unit_files,'com.apple.product-type.bundle.unit-test','xctest',dict(**common,PRODUCT_BUNDLE_IDENTIFIER='dev.gittok.core-tests',PRODUCT_NAME=q('$(TARGET_NAME)'),GENERATE_INFOPLIST_FILE='YES'),True)
ui=target('GitTokUITests',ui_files,'com.apple.product-type.bundle.ui-testing','xctest',dict(**common,PRODUCT_BUNDLE_IDENTIFIER='dev.gittok.ui-tests',PRODUCT_NAME=q('$(TARGET_NAME)'),GENERATE_INFOPLIST_FILE='YES',TEST_TARGET_NAME='GitTok'),False,[dependency])
configrefs=[]
for config in ['Debug','Release']:
    settings=dict(CLANG_ENABLE_MODULES='YES',SWIFT_OPTIMIZATION_LEVEL=q('-Onone' if config=='Debug' else '-O'),DEBUG_INFORMATION_FORMAT=q('dwarf' if config=='Debug' else 'dwarf-with-dsym'),ENABLE_TESTABILITY='YES' if config=='Debug' else 'NO')
    configrefs.append(put('project:'+config,obj(isa='XCBuildConfiguration',name=q(config),buildSettings=obj(**settings))))
project_config=put('project-configs',obj(isa='XCConfigurationList',buildConfigurations=refs(configrefs),defaultConfigurationIsVisible='0',defaultConfigurationName='Release'))
all_files=[key for key,value in objects.items() if 'isa = PBXFileReference' in value and 'SOURCE_ROOT' in value]
main=put('main-group',obj(isa='PBXGroup',children=refs(all_files+[ident('products-group')]),sourceTree=q('<group>')))
put('products-group',obj(isa='PBXGroup',children=refs(products),name='Products',sourceTree=q('<group>')))
put('project',obj(isa='PBXProject',attributes=obj(BuildIndependentTargetsInParallel='YES',LastUpgradeCheck='2600'),buildConfigurationList=project_config,compatibilityVersion=q('Xcode 14.0'),developmentRegion='en',hasScannedForEncodings='0',knownRegions='(en, Base)',mainGroup=main,packageReferences=refs([local_package]),productRefGroup=ident('products-group'),projectDirPath=q(''),projectRoot=q(''),targets=refs([app,unit,ui])))
project=ROOT/'GitTok.xcodeproj'
project.mkdir(exist_ok=True)
(project/'project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 60; objects = {\n'+'\n'.join(f'{key} = {value};' for key,value in objects.items())+'\n}; rootObject = '+ident('project')+'; }\n')
scheme=project/'xcshareddata/xcschemes/GitTok.xcscheme'
scheme.parent.mkdir(parents=True,exist_ok=True)
def buildref(name): return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{ident("target:"+name)}" BuildableName="{name+ (".app" if name=="GitTok" else ".xctest")}" BlueprintName="{name}" ReferencedContainer="container:GitTok.xcodeproj"/>'
scheme.write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildref('GitTok')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{buildref('GitTokCoreTests')}</TestableReference><TestableReference skipped="NO">{buildref('GitTokUITests')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildref('GitTok')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildref('GitTok')}</BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print('Generated GitTok.xcodeproj and shared GitTok scheme')
