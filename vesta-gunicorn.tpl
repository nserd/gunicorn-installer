server {
    listen      %ip%:%proxy_port%;
    server_name %domain_idn% %alias_idn%;

    error_log  /var/log/%web_system%/domains/%domain%.error.log error;
    access_log /var/log/%web_system%/domains/%domain%.log combined;
    access_log /var/log/%web_system%/domains/%domain%.bytes bytes;

    location / {
        proxy_pass      http://unix:/var/run/gunicorn/__projectName__.sock;
    }

    location /error/ {
        alias   %home%/%user%/web/%domain%/document_errors/;
    }

    location @fallback {
        proxy_pass      http://unix:/var/run/gunicorn/__projectName__.sock;
    }

    location ~ /\.ht    {return 404;}
    location ~ /\.svn/  {return 404;}
    location ~ /\.git/  {return 404;}
    location ~ /\.hg/   {return 404;}
    location ~ /\.bzr/  {return 404;}

    include %home%/%user%/conf/web/nginx.%domain%.conf*;
}
