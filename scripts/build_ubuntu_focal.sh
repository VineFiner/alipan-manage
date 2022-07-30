#!/bin/bash

# 构建镜像，指定 Dockerfile 文件路径 `./docker/Dockerfile`, 指定构建上下文目录 `./`
docker build -t vapor_app_ubuntu -f ./docker/Dockerfile ./

# 复制构建产物
docker create --name extract vapor_app_ubuntu
sudo docker cp extract:/app app
sudo chmod -R 775 app
docker rm -f extract

# 添加启动文件
touch ./app/scf_bootstrap && chmod +x ./app/scf_bootstrap
cat > ./app/scf_bootstrap<<EOF
#!/usr/bin/env bash
# export LD_LIBRARY_PATH=/opt/swift/usr/lib:${LD_LIBRARY_PATH}
./Run serve --env production --hostname 0.0.0.0 --port 9000
EOF

# 打包 资源目录 `./app`, 资源子目录 `./`
tar cvzf vapor_app_ubuntu.tar.gz -C ./app .

