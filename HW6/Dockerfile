FROM centos:7 AS builder

WORKDIR /root

RUN yum install -y redhat-lsb-core wget rpmdevtools rpm-build createrepo yum-utils gcc perl-IPC-Cmd perl-Data-Dumper

RUN wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.20.2-1.el7.ngx.src.rpm && rpm -i nginx-1.20.2-1.el7.ngx.src.rpm
RUN wget --no-check-certificate https://www.openssl.org/source/openssl-3.0.0.tar.gz && tar -xvf openssl-3.0.0.tar.gz

RUN yum-builddep -y rpmbuild/SPECS/nginx.spec

RUN sed -i 's/--with-debug/--with-openssl=\/root\/openssl-3.0.0 --with-debug/g' ./rpmbuild/SPECS/nginx.spec
RUN rpmbuild -bb rpmbuild/SPECS/nginx.spec


FROM centos/systemd:latest

EXPOSE 80

COPY --from=builder /root/rpmbuild/RPMS/x86_64/nginx-1.20.2-1.el7.ngx.x86_64.rpm /tmp
RUN yum localinstall -y /tmp/nginx-1.20.2-1.el7.ngx.x86_64.rpm; systemctl enable nginx

CMD ["/usr/sbin/init"]
