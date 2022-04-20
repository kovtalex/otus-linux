FROM python:3.6

WORKDIR /app

ENV PYTHONUNBUFFERED 1

RUN pip install Flask uwsgi && groupadd uwsgi && useradd -g uwsgi uwsgi && chown -R uwsgi:uwsgi /app

USER uwsgi

EXPOSE 9000

COPY --chown=uwsgi:uwsgi ./app .

ENTRYPOINT ["uwsgi"]
CMD ["--ini", "uwsgi.ini"]

