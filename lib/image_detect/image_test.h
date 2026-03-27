#ifndef __IMAGE_TEST_H__
#define __IMAGE_TEST_H__

/*
 * Get the version of image-test lib
 *
 * @return                  the version information
 */
const char* imagetest_getversion();

/*
 * Test one image with chessboard
 *
 * image_path               [in]   the input path of JPEG image
 * grid_x					[in]   the grid cells in x direction, default: 17
 * grid_y					[in]   the grid cells in x direction, default: 29
 * threshold                [in]   the threshold value, default: 1.0
 * output					[out]  the output value
 * @return                          0: PASS, otherwise: FAIL
 */
int imagetest_chessboard(const char* image_path, int grid_x, int grid_y, double threshold, double* output);

/*
 * Test one image with color chart
 *
 * image_path               [in]   the input path of JPEG image
 * threshold                [in]   the threshold value, default: 11.0
 * output					[out]  the output value
 * @return                          0: PASS, otherwise: FAIL
 */
int imagetest_color_chart(const char* image_path, double threshold, double* output);

/*
 * Test one image with resolution chart
 *
 * image_path               [in]   the input path of JPEG image
 * threshold                [in]   the threshold value, default: 700.0
 * output					[out]  the output value
 * @return                          0: PASS, otherwise: FAIL
 */
int imagetest_resolution_chart(const char* image_path, double threshold, double* output);

/*
 * Test one image with greyboard
 *
 * image_path               [in]   the input path of JPEG image
 * threshold                [in]   the threshold value, default: 0.68
 * output					[out]  the output value
 * @return                          0: PASS, otherwise: FAIL
 */
int imagetest_greyboard(const char* image_path, double threshold, double* output);

#endif
