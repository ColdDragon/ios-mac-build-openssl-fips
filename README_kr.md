iOS/Mac용 openssl(fips)을 빌드하는 방법

주 내용은 https://wiki.openssl.org/index.php/Android 를 참조하였습니다.

테스트 환경 : CentOS release 6.7

Openssl : openssl-1.0.2n, openssl-fips-ecp-2.0.16(특허 문제)

- 절차

1. home/user{XXX}/openssl 폴더를 만들고 이동

2. script download(openssl-build-fips.sh)

3. openssl-build-fips.sh {yes|no} {yes|no} {ios sdk version} {macos sdk version} 실행

- openssl-build-fips.sh 상세 옵션

1. bitcode : bitcode 라이브러리

2. fips mode : fips 지원 라이브러리를 만듬

3. ios sdk version : 기본값(11.2)

4. macos sdk version : 기본값(10.13)

