# Umi-OCR Docker
# https://github.com/hiroi-sora/Umi-OCR
# https://github.com/hiroi-sora/Umi-OCR_runtime_linux

FROM debian:12.10-slim

LABEL app="Umi-OCR-Paddle"
LABEL maintainer="hiroi-sora"
LABEL version="2.1.5"
LABEL description="OCR software, free and offline."
LABEL license="MIT"
LABEL org.opencontainers.image.source="https://github.com/hiroi-sora/Umi-OCR_runtime_linux"

# 安装所需工具和QT依赖库
RUN apt-get update && apt-get install -y \
    wget xz-utils ttf-wqy-microhei xvfb \
    libglib2.0-0 libgssapi-krb5-2 libgl1-mesa-glx libfontconfig1 \
    libfreetype6 libxcb-icccm4 libxcb-image0 libxcb-keysyms1 \
    libxcb-render-util0 libxcb-render0 libxcb-shape0 libxcb-xkb1 \
    libxcb-xinerama0 libxkbcommon-x11-0 libxkbcommon0 libdbus-1-3 \
    netcat-traditional gnupg curl unzip xvfb libgconf-2-4  libxss1 libnss3 libnspr4  libasound2  libatk1.0-0 \
    libatk-bridge2.0-0 libcups2 libdbus-1-3 libdrm2 libgbm1 libgtk-3-0 libxcomposite1 \
    libxdamage1 libxfixes3 libxrandr2 xdg-utils fonts-liberation dbus xauth xvfb x11vnc tigervnc-tools supervisor \
    net-tools procps git python3-numpy fontconfig fonts-dejavu fonts-dejavu-core fonts-dejavu-extra vim git \
    && rm -rf /var/lib/apt/lists/*

# Install noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc \
    && git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify \
    && ln -s /opt/novnc/vnc.html /opt/novnc/index.html

# 工作目录
WORKDIR /app

# 可选1：将主机目录中的发行包，复制到容器内
# COPY Umi-OCR_Linux_Paddle_2.1.5.tar.xz .
# 可选2：在线下载发行包
RUN wget https://github.com/hiroi-sora/Umi-OCR/releases/download/v2.1.5/Umi-OCR_Linux_Paddle_2.1.5.tar.xz

# 解压压缩包，移动文件，删除多余的目录和压缩包
RUN tar -v -xf Umi-OCR_Linux_Paddle_2.1.5.tar.xz && \
    mv Umi-OCR_Linux_Paddle_2.1.5/* . && \
    rmdir Umi-OCR_Linux_Paddle_2.1.5 && \
    rm Umi-OCR_Linux_Paddle_2.1.5.tar.xz

# 下载最新的启动脚本
# RUN wget -O umi-ocr.sh https://raw.githubusercontent.com/hiroi-sora/Umi-OCR_runtime_linux/main/umi-ocr.sh

# 写入 Umi-OCR 预配置项：
#    允许外部HTTP请求
#    切换到支持中文的字体
RUN printf "\
[Global]\n\
server.host=0.0.0.0\n\
ui.fontFamily=WenQuanYi Micro Hei\n\
ui.dataFontFamily=WenQuanYi Micro Hei\n\
" > ./UmiOCR-data/.settings

ENV DISPLAY=:99
ENV VNC_PASSWORD=vncpassword
ENV RESOLUTION=1920x1080x24
ENV RESOLUTION_WIDTH=1920
ENV RESOLUTION_HEIGHT=1080

# Set up supervisor configuration
RUN mkdir -p /var/log/supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY web /app/web/
COPY proxy.py /app/

EXPOSE 8080 6080

# 运行指令
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
