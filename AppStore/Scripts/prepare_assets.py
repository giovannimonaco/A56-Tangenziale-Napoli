#!/usr/bin/env python3
"""Upload and place App Store artwork, without any review or release operation.

Requires requirements.txt. Credentials come only from ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_PATH in the environment.
Manifest stores asset IDs and SHA-256 hashes, never credentials or signed upload URLs.
"""
import argparse, concurrent.futures, hashlib, json, threading, time
from pathlib import Path
from PIL import Image
from asc_client import Connect, ROOT
MANIFEST=ROOT/'AppStore/UploadManifest.json'
GROUPS={'iPhone-6.9':'IPHONE_DYNAMIC_ISLAND_LARGE_PROFILE',
        'iPhone-6.3':'IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE'}
SIZES={'iPhone-6.9':(1320,2868),'iPhone-6.3':(1206,2622)}
WORKER=threading.local()
CREATIVE={'header-3840x1646.png':'PRODUCT_PAGE_HEADER_ASSET',
          'search-results-3840x2560.png':'APP_STORE_SEARCH_RESULTS_ASSET'}


def all_data(c,path,**params):
    result=[]
    while path:
        page=c.get(path,**params);result+=page['data']
        path=page.get('links',{}).get('next');params={}
        if path: path=path.replace('https://api.appstoreconnect.apple.com','')
    return result


def save(manifest):
    MANIFEST.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')


def upload(file,category,reference,existing_id=None):
    if not hasattr(WORKER,'client'): WORKER.client=Connect()
    c=WORKER.client;file=Path(file)
    resource='appAssetLibraryImages'
    asset=c.get('/v1/'+resource+'/'+existing_id)['data'] if existing_id else c.request('POST','/v1/'+resource,json={'data':{'type':resource,
      'attributes':{'fileName':file.name,'fileSize':file.stat().st_size,'category':category,'referenceName':reference},
      'relationships':{'assetLibrary':{'data':{'type':'appAssetLibraries','id':'6782002695'}}}}})['data']
    import requests
    content=file.read_bytes()
    for op in asset['attributes']['uploadOperations']:
        try:
            r=requests.request(op['method'],op['url'],headers={h['name']:h['value'] for h in op['requestHeaders']},
                               data=content[op['offset']:op['offset']+op['length']],timeout=120)
        except requests.RequestException:
            raise RuntimeError(f'Upload network error for {reference}; signed URL omitted') from None
        if not r.ok: raise RuntimeError(f'Upload failed for {reference}: HTTP {r.status_code}')
    c.request('PATCH',f"/v1/{resource}/{asset['id']}",json={'data':{'type':resource,'id':asset['id'],'attributes':{'uploaded':True}}})
    print('Uploaded',reference,asset['id'],flush=True)
    return asset['id']


def ready(c,asset_id):
    for attempt in range(45):
        asset=c.get('/v1/appAssetLibraryImages/'+asset_id)['data']
        state=asset['attributes']['state']
        if state in ['PREPARE_FOR_SUBMISSION','APPROVED']: return asset
        if state not in ['UPLOAD_COMPLETE','AWAITING_UPLOAD','PROCESSING']:
            raise RuntimeError(f"Image {asset_id}: {state} {asset['attributes'].get('stateDetails')}")
        time.sleep(2)
    raise RuntimeError(f'Processing timeout: {asset_id}')


def main():
    p=argparse.ArgumentParser();p.add_argument('command',choices=['screenshots','creative','audit']);p.add_argument('--devices',nargs='+',choices=list(GROUPS),default=list(GROUPS));args=p.parse_args()
    c=Connect();app,version=c.context()
    if version['attributes']['appStoreState']!='PREPARE_FOR_SUBMISSION':
        raise RuntimeError('App Store version is not editable in the expected state')
    locales=all_data(c,f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")
    manifest=json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {'assets':{}}
    if args.command=='audit':
        report={}
        for loc in locales:
            placements=all_data(c,f"/v1/appStoreVersionLocalizations/{loc['id']}/placements",include='image',limit=200,sort='placementGroupPosition')
            report[loc['attributes']['locale']]=placements
            counts={}
            for placement in placements:
                attrs=placement['attributes'];key=attrs['placementType']+'/'+attrs['placementGroup']
                counts[key]=counts.get(key,0)+1
            print(loc['attributes']['locale'],counts,flush=True)
        images=all_data(c,f"/v1/appAssetLibraries/{app['id']}/images",limit=200)
        (ROOT/'build/asc-final-assets.json').write_text(json.dumps({'placements':report,'images':images},indent=2))
        print('Asset states:',{s:sum(a['attributes']['state']==s for a in images) for s in {a['attributes']['state'] for a in images}})
        return
    specs=[]
    if args.command=='creative':
        for name,placement in CREATIVE.items():
            specs.append((ROOT/'AppStore/CreativeAssets'/name,'CREATIVE_ASSETS','creative/'+name))
    else:
        for loc in locales:
            locale=loc['attributes']['locale']
            for prefix in args.devices:
                files=sorted((ROOT/'AppStore/Screenshots'/locale).glob(prefix+'-*.png'))
                if len(files)!=4: raise RuntimeError(f'{locale}/{prefix}: expected four files, got {len(files)}')
                for file in files:
                    with Image.open(file) as image:
                        if image.size!=SIZES[prefix]: raise RuntimeError(f'Wrong screenshot dimensions: {file}: {image.size}')
                        if image.mode!='RGB': raise RuntimeError(f'Image must be RGB without alpha: {file}')
                    specs.append((file,'APP_SCREENSHOTS_AND_PREVIEWS',locale+'/'+file.name))
    pending=[]
    # References are deterministic and include a content hash, allowing interrupted runs to resume.
    known=all_data(c,f"/v1/appAssetLibraries/{app['id']}/images",limit=200)
    for file,category,key in specs:
        digest=hashlib.sha256(file.read_bytes()).hexdigest();reference='A56/'+key+'/'+digest[:12]
        entry=manifest['assets'].get(key)
        if entry and entry['sha256']==digest:
            continue
        reused=next((a for a in known if a['attributes'].get('referenceName')==reference
                     and a['attributes']['state']!='FAILED'),None)
        if reused and reused['attributes']['state']!='AWAITING_UPLOAD':
            manifest['assets'][key]={'id':reused['id'],'sha256':digest};save(manifest)
        else: pending.append((file,category,key,digest,reference,reused['id'] if reused else None))
    errors=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
        futures={pool.submit(upload,file,category,reference,existing):(key,digest) for file,category,key,digest,reference,existing in pending}
        for future in concurrent.futures.as_completed(futures):
            key,digest=futures[future]
            try: asset_id=future.result()
            except Exception as error:
                errors.append(key);print('Upload needs retry:',key,type(error).__name__,flush=True);continue
            manifest['assets'][key]={'id':asset_id,'sha256':digest};save(manifest)
    if errors: raise RuntimeError(f'{len(errors)} uploads need retry; completed uploads saved in manifest')
    assets={key:ready(c,manifest['assets'][key]['id']) for _,_,key in specs}
    for loc in locales:
        locale=loc['attributes']['locale']
        placements=all_data(c,f"/v1/appStoreVersionLocalizations/{loc['id']}/placements",include='image',limit=200)
        targets=[]
        if args.command=='creative':
            for name,placement in CREATIVE.items():targets.append((placement,'DEFAULT_PROFILE',['creative/'+name]))
        else:
            for prefix in args.devices:
                group=GROUPS[prefix]
                keys=sorted(k for k in assets if k.startswith(locale+'/'+prefix+'-'))
                targets.append(('APP_SCREENSHOT',group,keys))
        for placement_type,group,keys in targets:
            current=[x for x in placements if x['attributes']['placementType']==placement_type and x['attributes']['placementGroup']==group]
            wanted=[manifest['assets'][k]['id'] for k in keys]
            # Removing placements leaves originals intact in Asset Library and is reversible.
            for old in current:
                if old['relationships'].get('image',{}).get('data',{}).get('id') not in wanted:
                    c.request('DELETE','/v1/appAssetLibraryPlacements/'+old['id'])
                    print('Replaced placement',locale,group,old['id'],flush=True)
            ordered=[]
            for asset_id in wanted:
                existing=next((x for x in current if x['relationships'].get('image',{}).get('data',{}).get('id')==asset_id),None)
                if not existing:
                    existing=c.request('POST','/v1/appAssetLibraryPlacements',json={'data':{'type':'appAssetLibraryPlacements',
                      'attributes':{'placementType':placement_type,'placementGroup':group},
                      'relationships':{'image':{'data':{'type':'appAssetLibraryImages','id':asset_id}},
                      'appStoreVersionLocalization':{'data':{'type':'appStoreVersionLocalizations','id':loc['id']}}}}})['data']
                ordered.append({'type':'appAssetLibraryPlacements','id':existing['id']})
            if placement_type=='APP_SCREENSHOT':
                c.request('POST','/v1/appAssetLibraryPlacementOrderingRequests',json={'data':{
                  'type':'appAssetLibraryPlacementOrderingRequests','attributes':{'placementGroup':group},
                  'relationships':{'orderedPlacements':{'data':ordered},'appStoreVersionLocalization':{
                    'data':{'type':'appStoreVersionLocalizations','id':loc['id']}}}}})
            print('Placed',locale,placement_type,group,len(ordered),flush=True)
    print('Finished preparation. Nothing submitted for review.',flush=True)
if __name__=='__main__':main()
