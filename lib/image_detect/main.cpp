#include <iostream>
#include "image_test.h"

using namespace std;

int main(int argc, char** argv) {
    int ret = 0;
    
    printf("version: %s\n", imagetest_getversion());

    ret = imagetest_chessboard("samples/chessboard.png", 1.0);
    if (ret == 0)
        cout << "Chessboard: PASS" << endl;
    else
        cout << "Chessboard: FAIL" << endl;

    ret = imagetest_color_chart("samples/colorchart.png", 11.0);
    if (ret == 0)
        cout << "Color Chart: PASS" << endl;
    else
        cout << "Color Chart: FAIL" << endl;

    ret = imagetest_resolution_chart("samples/resolutionchart.png", 700.0);
    if (ret == 0)
        cout << "Resolution Chart: PASS" << endl;
    else
        cout << "Resolution Chart: FAIL" << endl;

    ret = imagetest_greyboard("samples/greyboard.png", 0.68);
    if (ret==0)
        cout << "Greyboard: PASS" << endl;
    else
        cout << "Greyboard: FAIL" << endl;

    return 0;
}
