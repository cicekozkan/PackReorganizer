# -*- coding: utf-8 -*-
"""
Created on Sun Nov 15 12:20:50 2015

@author: asus
"""

import re

def is_comment(comment):
    pattern = '[1-3]_[0-9]{5}'
    m = re.match(pattern,comment)
    if m == None:
        return False
    else:
        return m.group(0) == comment
