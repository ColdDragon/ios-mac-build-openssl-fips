iOS/Mac용 openssl(fips)을 빌드하는 방법

주 내용은 https://wiki.openssl.org/index.php/Compilation_and_Installation 를 참조하였습니다.

테스트 환경 : macOS High Sierra V 10.13.6 Xcode 9.2 

Openssl : openssl-1.0.2q, openssl-fips-ecp-2.0.16(특허 문제)

- 절차

1. home/user{XXX}/openssl 폴더를 만들고 이동

2. script download(openssl-build-fips.sh)

3. openssl-build-fips.sh {yes|no} {yes|no} {ios sdk version} {macos sdk version} 실행

- openssl-build-fips.sh 상세 옵션

1. bitcode : bitcode 라이브러리

2. fips mode : fips 지원 라이브러리를 만듬

3. ios sdk version : 기본값(11.2)

4. macos sdk version : 기본값(10.13)


ui 절차

1. fips모드 적용을 위해선 incore_macho를 i386으로 빌드한 후 /usr/local/bin에 넣어두고 이후에 사용

2. fips_premain.c는 ui에서 최종 실행파일을 만들 때 같이 빌드해야 하고 fips모드로 빌드한 libcrypto.a파일도 이 때 같이 링크해야 함

3. fips_pi툴을 통해 fingerprint가 유효한지 
