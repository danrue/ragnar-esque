# https://qa-reports.linaro.org/lkft/linux-next-oe/tests/kselftest/test_xdp_meta.sh

export URL=http://snapshots.linaro.org/openembedded/lkft/morty/hikey/rpb/linux-next/237
export LINUX_GIT_URL=git://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
export LINUX_GIT_REFERENCE=/home/drue/src/linux/mainline

export BAD=next-20180413
export GOOD=next-20180411
export LAVA_JOB=job_209256.yaml
export LAVA_TEST_SUITE="1_bisect"
export LAVA_TEST_CASE="bisect"
