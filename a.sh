#!/bin/bash

# 创建新的孤立分支
git checkout --orphan new_history_branch
# 获取所有标签及其指向的commit hash
tags=$(git show-ref --tags -d | grep -v '\^{}' | cut -d' ' -f2)

# 遍历所有标签，将它们的commit历史转移到新分支
for tag in $tags; do
  tagname=$(git describe --tags "$tag")
  echo "Processing tag: $tagname"
  
  # 检出标签
  git checkout "$tag"
  
  # 将当前标签状态(指向的commit)作为新的历史的一部分
  git checkout new_history_branch
  git merge --allow-unrelated-histories -s ours "$tag" --no-commit
  git commit --amend -m "Preserved original tag: $tagname"
done

# 删除原有的主分支并将新分支命名为主分支
# git branch -D main
# git branch -m main

# 强制推送新的主分支到远程仓库
# git push -f origin main

echo "All done. The main branch now has a new history, preserving all tags."
