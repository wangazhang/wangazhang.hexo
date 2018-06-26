cd /Users/qianzhang/Documents/opt/hexo/wangazhang
hexo clean
hexo deploy
git add .
git commit -m 'add'
git push -f
cp ~/Documents/opt/hexo/wangazhang/source/_posts/小电开发规范.md /Users/qianzhang/IdeaProjects/rules/README.md
cd /Users/qianzhang/IdeaProjects/rules
git add .
git commit -m 'add'
git push
