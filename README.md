# Установщик WSGI-сервера Gunicorn

Устанавливает gunicorn в виртуальное окружение проекта, создает сервис и настраивает ротацию логов. Если на сервере есть VestaCP, то создает для неё специальный шаблон.
```
gunicorn-installer.sh [options] <project-dir>
```

`project-dir` - **абсолютный** путь к папке проекта

Опции:
* `--web-user`, `-w` - пользователь, от которого будет работать WSGI-сервер (По умолчанию: `www-data` или `admin` в случае VestaCP)
* `--venv`, `-v` - абсолютный путь к виртуальному окружению (По умоланию: окружение создается/используется в папке `venv`, внутри директории проекта)
* `--help`, `-h` - вывести данный текст и завершить скрипт
