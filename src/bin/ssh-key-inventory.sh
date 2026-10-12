#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Dascos
set -euo pipefail
python3 - <<'PY'
import hashlib,json,os,stat
paths=[]
for p in ['/root/.ssh/authorized_keys']:
    if os.path.isfile(p): paths.append(p)
try:
    for name in os.listdir('/home'):
        p=os.path.join('/home',name,'.ssh','authorized_keys')
        if os.path.isfile(p): paths.append(p)
except FileNotFoundError:
    pass
for p in sorted(set(paths)):
    try:
        st=os.stat(p, follow_symlinks=False)
        if not stat.S_ISREG(st.st_mode):
            continue
        h=hashlib.sha256()
        with open(p,'rb') as f:
            for chunk in iter(lambda:f.read(131072),b''): h.update(chunk)
        rec={"path":p,"sha256":h.hexdigest(),"uid":st.st_uid,"gid":st.st_gid,"mode":format(stat.S_IMODE(st.st_mode),'04o')}
        print(json.dumps(rec,sort_keys=True,separators=(',',':')))
    except (FileNotFoundError,PermissionError,OSError) as e:
        print(json.dumps({"path":p,"error":str(e)},sort_keys=True,separators=(',',':')))
PY
