; ModuleID = '../examples/ex02.c'
target datalayout = "e-m:o-i64:64-f80:128-n8:16:32:64-S128"
target triple = "x86_64-apple-macosx10.11.0"

; Function Attrs: nounwind ssp uwtable
define i32 @main() #0 {
  %1 = alloca i32, align 4
  %ia = alloca i32, align 4
  %ib = alloca i32, align 4
  %iSum = alloca i32, align 4
  %iDif = alloca i32, align 4
  %iMul = alloca i32, align 4
  %iDiv = alloca i32, align 4
  store i32 0, i32* %1, align 4
  store i32 1, i32* %ia, align 4
  store i32 2, i32* %ib, align 4
  %2 = load i32, i32* %ia, align 4
  %3 = load i32, i32* %ib, align 4
  %4 = add nsw i32 %2, %3
  store i32 %4, i32* %iSum, align 4
  %5 = load i32, i32* %ia, align 4
  %6 = load i32, i32* %ib, align 4
  %7 = sub nsw i32 %5, %6
  store i32 %7, i32* %iDif, align 4
  %8 = load i32, i32* %ia, align 4
  %9 = load i32, i32* %ib, align 4
  %10 = mul nsw i32 %8, %9
  store i32 %10, i32* %iMul, align 4
  %11 = load i32, i32* %ia, align 4
  %12 = load i32, i32* %ib, align 4
  %13 = sdiv i32 %11, %12
  store i32 %13, i32* %iDiv, align 4
  %14 = load i32, i32* %iSum, align 4
  ret i32 %14
}

; Function Attrs: nounwind ssp uwtable
define double @mainDouble() #0 {
  %da = alloca double, align 8
  %db = alloca double, align 8
  %dSum = alloca double, align 8
  %dDif = alloca double, align 8
  %dMul = alloca double, align 8
  %dDiv = alloca double, align 8
  store double 1.000000e+00, double* %da, align 8
  store double 2.000000e+00, double* %db, align 8
  %1 = load double, double* %da, align 8
  %2 = load double, double* %db, align 8
  %3 = fadd double %1, %2
  store double %3, double* %dSum, align 8
  %4 = load double, double* %da, align 8
  %5 = load double, double* %db, align 8
  %6 = fsub double %4, %5
  store double %6, double* %dDif, align 8
  %7 = load double, double* %da, align 8
  %8 = load double, double* %db, align 8
  %9 = fmul double %7, %8
  store double %9, double* %dMul, align 8
  %10 = load double, double* %da, align 8
  %11 = load double, double* %db, align 8
  %12 = fdiv double %10, %11
  store double %12, double* %dDiv, align 8
  %13 = load double, double* %dSum, align 8
  ret double %13
}

; Function Attrs: nounwind ssp uwtable
define zeroext i1 @mainBool() #0 {
  %ba = alloca i8, align 1
  %bb = alloca i8, align 1
  %bSum = alloca i8, align 1
  %bDif = alloca i8, align 1
  %bMul = alloca i8, align 1
  %bDiv = alloca i8, align 1
  store i8 1, i8* %ba, align 1
  store i8 0, i8* %bb, align 1
  %1 = load i8, i8* %ba, align 1
  %2 = trunc i8 %1 to i1
  %3 = zext i1 %2 to i32
  %4 = load i8, i8* %bb, align 1
  %5 = trunc i8 %4 to i1
  %6 = zext i1 %5 to i32
  %7 = add nsw i32 %3, %6
  %8 = icmp ne i32 %7, 0
  %9 = zext i1 %8 to i8
  store i8 %9, i8* %bSum, align 1
  %10 = load i8, i8* %ba, align 1
  %11 = trunc i8 %10 to i1
  %12 = zext i1 %11 to i32
  %13 = load i8, i8* %bb, align 1
  %14 = trunc i8 %13 to i1
  %15 = zext i1 %14 to i32
  %16 = sub nsw i32 %12, %15
  %17 = icmp ne i32 %16, 0
  %18 = zext i1 %17 to i8
  store i8 %18, i8* %bDif, align 1
  %19 = load i8, i8* %ba, align 1
  %20 = trunc i8 %19 to i1
  %21 = zext i1 %20 to i32
  %22 = load i8, i8* %bb, align 1
  %23 = trunc i8 %22 to i1
  %24 = zext i1 %23 to i32
  %25 = mul nsw i32 %21, %24
  %26 = icmp ne i32 %25, 0
  %27 = zext i1 %26 to i8
  store i8 %27, i8* %bMul, align 1
  %28 = load i8, i8* %ba, align 1
  %29 = trunc i8 %28 to i1
  %30 = zext i1 %29 to i32
  %31 = load i8, i8* %bb, align 1
  %32 = trunc i8 %31 to i1
  %33 = zext i1 %32 to i32
  %34 = sdiv i32 %30, %33
  %35 = icmp ne i32 %34, 0
  %36 = zext i1 %35 to i8
  store i8 %36, i8* %bDiv, align 1
  %37 = load i8, i8* %bSum, align 1
  %38 = trunc i8 %37 to i1
  ret i1 %38
}

attributes #0 = { nounwind ssp uwtable "disable-tail-calls"="false" "less-precise-fpmad"="false" "no-frame-pointer-elim"="true" "no-frame-pointer-elim-non-leaf" "no-infs-fp-math"="false" "no-nans-fp-math"="false" "stack-protector-buffer-size"="8" "target-cpu"="core2" "target-features"="+cx16,+fxsr,+mmx,+sse,+sse2,+sse3,+ssse3" "unsafe-fp-math"="false" "use-soft-float"="false" }

!llvm.module.flags = !{!0}
!llvm.ident = !{!1}

!0 = !{i32 1, !"PIC Level", i32 2}
!1 = !{!"Apple LLVM version 7.3.0 (clang-703.0.31)"}
