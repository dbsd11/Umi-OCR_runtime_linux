import argparse
import os
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse, urljoin
import http.client
from functools import partial

class CustomHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, proxies=None, **kwargs):
        self.proxies = proxies or {}
        # 显式传递 directory 参数给父类
        super().__init__(*args, **kwargs)

    def do_GET(self):
        for path_prefix, target_url in self.proxies.items():
            if self.path.startswith(path_prefix):
                self.proxy_request(path_prefix, target_url)
                return
        super().do_GET()

    def do_POST(self):
        for path_prefix, target_url in self.proxies.items():
            if self.path.startswith(path_prefix):
                self.proxy_request(path_prefix, target_url)
                return
        self.send_error(404, "File not found")

    def proxy_request(self, path_prefix, target_url):
        parsed = urlparse(target_url)
        target_host = parsed.netloc
        target_path = urljoin(parsed.path, self.path)

        try:
            conn = http.client.HTTPConnection(target_host)
            headers = {k: v for k, v in self.headers.items()}
            content_length = int(headers.get('Content-Length', 0))
            conn.request(
                self.command,
                target_path,
                body=self.rfile.read(content_length),
                headers=headers
            )
            resp = conn.getresponse()

            self.send_response(resp.status)
            for header, value in resp.getheaders():
                self.send_header(header, value)
            self.end_headers()

            while chunk := resp.read(4096):
                self.wfile.write(chunk)
        except Exception as e:
            self.send_error(500, f"Proxy error: {str(e)}")
        finally:
            conn.close()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('-p', '--port', type=int, default=8000)
    parser.add_argument('-d', '--directory', type=str, default=os.getcwd())
    parser.add_argument('-t', '--proxy', action='append', help="反向代理规则，例如：/api:http://localhost:8080")
    args = parser.parse_args()

    # 解析代理规则
    proxies = {}
    if args.proxy:
        for rule in args.proxy:
            if ':' not in rule:
                print(f"无效代理规则: {rule}")
                sys.exit(1)
            path_prefix, target_url = rule.split(':', 1)
            proxies[path_prefix] = target_url

    # 验证目录
    if not os.path.isdir(args.directory):
        print(f"目录不存在: {args.directory}")
        sys.exit(1)

    # 使用 partial 固定参数
    handler = partial(
        CustomHandler,
        directory=args.directory,  # 关键参数，Python 3.7+ 支持
        proxies=proxies
    )

    with HTTPServer(('', args.port), handler) as httpd:
        print(f"服务器运行在端口 {args.port}")
        print(f"静态文件目录: {args.directory}")
        if proxies:
            print("反向代理规则:")
            for path, target in proxies.items():
                print(f"  {path} -> {target}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n服务器已停止")

if __name__ == '__main__':
    main()
