# typed: false
# frozen_string_literal: true

class MuslCrossS390x < Formula
  desc "Linux cross compilers based on musl libc"
  homepage "https://github.com/richfelker/musl-cross-make"
  url "https://github.com/richfelker/musl-cross-make/archive/refs/tags/v0.9.9.tar.gz"
  sha256 "ff3e2188626e4e55eddcefef4ee0aa5a8ffb490e3124850589bcaf4dd60f5f04"
  revision 2
  head "https://github.com/richfelker/musl-cross-make.git"
 
  option "without-s390x", "Build cross-compilers targeting s390x-linux-musl"
  bottle do
    sha256 cellar: :any_skip_relocation, arm64_sonoma: "fb51f57f157175e4a34a6447b9b7a3ef05a817774020067f0b45b411f8cc2836"
  end
  depends_on "gnu-sed" => :build
  depends_on "make" => :build

  resource "linux-4.19.88.tar.xz" do
    url "https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.19.88.tar.xz"
    sha256 "c1923b6bd166e6dd07be860c15f59e8273aaa8692bc2a1fce1d31b826b9b3fbe"
  end

  resource "mpfr-4.0.2.tar.bz2" do
    url "https://ftp.gnu.org/gnu/mpfr/mpfr-4.0.2.tar.bz2"
    sha256 "c05e3f02d09e0e9019384cdd58e0f19c64e6db1fd6f5ecf77b4b1c61ca253acc"
  end

  resource "mpc-1.1.0.tar.gz" do
    url "https://ftp.gnu.org/gnu/mpc/mpc-1.1.0.tar.gz"
    sha256 "6985c538143c1208dcb1ac42cedad6ff52e267b47e5f970183a3e75125b43c2e"
  end

  resource "gmp-6.1.2.tar.bz2" do
    url "https://ftp.gnu.org/gnu/gmp/gmp-6.1.2.tar.bz2"
    sha256 "5275bb04f4863a13516b2f39392ac5e272f5e1bb8057b18aec1c9b79d73d8fb2"
  end

  resource "musl-1.2.0.tar.gz" do
    url "https://www.musl-libc.org/releases/musl-1.2.0.tar.gz"
    sha256 "c6de7b191139142d3f9a7b5b702c9cae1b5ee6e7f57e582da9328629408fd4e8"
  end

  resource "binutils-2.33.1.tar.bz2" do
    url "https://ftp.gnu.org/gnu/binutils/binutils-2.33.1.tar.bz2"
    sha256 "0cb4843da15a65a953907c96bad658283f3c4419d6bcc56bf2789db16306adb2"
  end

  resource "config.sub" do
    url "https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.sub;hb=3d5db9ebe860"
    sha256 "75d5d255a2a273b6e651f82eecfabf6cbcd8eaeae70e86b417384c8f4a58d8d3"
  end

  resource "gcc-9.2.0.tar.xz" do
    url "https://ftp.gnu.org/gnu/gcc/gcc-9.2.0/gcc-9.2.0.tar.xz"
    sha256 "ea6ef08f121239da5695f76c9b33637a118dcf63e24164422231917fa61fb206"
  end

  resource "isl-0.21.tar.bz2" do
    url "https://downloads.sourceforge.net/project/libisl/isl-0.21.tar.bz2"
    sha256 "d18ca11f8ad1a39ab6d03d3dcb3365ab416720fcb65b42d69f34f51bf0a0e859"
  end

  patch do # disable arm vdso in musl 1.2.0
    url "https://github.com/richfelker/musl-cross-make/commit/d6ded50d.patch?full_index=1"
    sha256 "6a1ab78f59f637c933582db515dd0d5fe4bb6928d23a9b02948b0cdb857466c8"
  end

  patch do # use CURDIR instead of PWD
    url "https://github.com/richfelker/musl-cross-make/commit/a54eb56f.patch?full_index=1"
    sha256 "a4e3fc7c37dac40819d23bd022122c17c783f58dda4345065fec6dca6abce36c"
  end

  patch do # Apple Silicon build fix for gcc-6.5.0 .. gcc-10.3.0
    url "https://github.com/richfelker/musl-cross-make/commit/8d34906.patch?full_index=1"
    sha256 "01b2e0e11aeb33db5d8988d42a517828911601227238d8e7d5d7db8364486c26"
  end

  def install
    targets = []
    targets.push "s390x-linux-musl" if build.with? "s390x"

    (buildpath/"resources").mkpath
    resources.each do |resource|
      cp resource.fetch, buildpath/"resources"/resource.name
    end

    (buildpath/"config.mak").write <<~EOS
      SOURCES = #{buildpath/"resources"}
      OUTPUT = #{libexec}

      # Drop some features for faster and smaller builds
      COMMON_CONFIG += --disable-nls
      GCC_CONFIG += --disable-libquadmath --disable-decimal-float
      GCC_CONFIG += --disable-libitm --disable-fixed-point

      # Keep the local build path out of binaries and libraries
      COMMON_CONFIG += --with-debug-prefix-map=#{buildpath}=

      # Explicitly enable libisl support to avoid opportunistic linking
      ISL_VER = 0.21

      # https://llvm.org/bugs/show_bug.cgi?id=19650
      # https://github.com/richfelker/musl-cross-make/issues/11
      ifeq ($(shell $(CXX) -v 2>&1 | grep -c "clang"), 1)
      TOOLCHAIN_CONFIG += CXX="$(CXX) -fbracket-depth=512"
      endif
    EOS

    ENV.prepend_path "PATH", "#{Formula["gnu-sed"].opt_libexec}/gnubin"
    targets.each do |target|
      system Formula["make"].opt_bin/"gmake", "install", "TARGET=#{target}"
    end

    bin.install_symlink Dir["#{libexec}/bin/*"]
  end

  test do
    (testpath/"hello.c").write <<~EOS
      #include <stdio.h>

      int main()
      {
          printf("Hello, world!");
      }
    EOS
    system "#{bin}/s390x-linux-musl-cc", (testpath/"hello.c") if build.with? "s390x"
  end
end
