
//    X = STR2DOUBLEQ(S) converts the string S, which should be an
//    ASCII character representation of a real value, to MATLAB's double
//    representation.  The string may contain digits,a decimal point, 
//    a leading + or - sign and 'e' preceding a power of 10 scale factor
// 
//    X = STR2DOUBLEQ(C) converts the strings in the cell array of strings 
//    C to double.  The matrix X returned will be the same size as C.  
//    NaN will be returned for any cell which is not a string representing 
//    a valid scalar value. NaN will be returned for individual cells in 
//    C which are cell arrays.
    
//    Examples
//       str2doubleq('3.14159')
//	     str2doubleq('  2 i   +   4.23e2  ')
//		 str2doubleq('  2 +  i4     ')
//       str2doubleq({'2e10' '3.1415'})
//       str2doubleq(' j4     ')
//		 str2doubleq('100+ 10E2i')
//		 str2doubleq('1.25e10')

#include "mex.h"
#include <cmath>
/* Please uncomment the following #define directive line
   USE_PARALLEL_ALGORITHM if you wish to compile algorithm 
   in parallel computation mode. If this is enabled either 
   you need to have 
		- boost library installed (please see http://www.boost.org/ 
		  instructions to build boost library or if using Visual Studio, 
		  just download precompiled binaries from http://www.boostpro.com/download/ 
		  using latest installer)
		- compiler that supports C++11 native threads

*/
//#define USE_PARALLEL_ALGORITHM

/* Please uncomment the following #define directive 
   ENSURE_THREAD_SAFE_MEX if you are using USE_PARALLEL_ALGORITHM
   and you are experiencing Matlab crash during calls to str2doubleq.
   Atleast with version 2012b Matlab does not crash with simultaneous 
   threads calling functions in mex.h
   The following macro compiles the source ensuring thread safeness in
   Matlab runtime. Also note that if ENSURE_THREAD_SAFE_MEX is undefined
   algorithm is considerably more faster!
*/
//#define ENSURE_THREAD_SAFE_MEX 

static const double NaN =  mxGetNaN();

inline bool is_null_or_blank(const char*& s) {
	if (!s)
		return true;
	while (*s)
		if (!(*s == '\t' || *s == ' '))
			return false;
		else
			++s;
	return true;
}

inline void remove_blanks(const char*& s) {
	while (*s == '\t' || *s == ' ') 
        s++;
}

bool parse_to_double(const char*& s , double& dval, bool& is_imaginary) {
    dval = 0;
    is_imaginary = false;
	if (!s)
        return false;
    remove_blanks(s);
	bool is_negative = false;
    switch (*s) {
        case '-':
            is_negative = true;
		case '+':
            ++s;
    } 
	remove_blanks(s);
    if (*s == 'i' || *s == 'j') {
        ++s;
		is_imaginary = true;
	}
	remove_blanks(s);
	/* skip trailing zeros*/
    while (*s == '0') 
        s++;
	/* whole part is processed in doubles to avoid overflows */
    while (*s >= '0' && *s <= '9') {
        dval *= 10;
        dval += (double) (*s++ - '0');
    }
    if (*s == '.' || *s == ',') {
        s++;
        /* decimal part */
        double decimal = 0;
        double divisor = 1;
        while (*s >= '0' && *s <= '9') {
            divisor *= 10;
            decimal *= 10;
            decimal += (double) (*s++ - '0');
        }
        dval += decimal / divisor;
    }
    if(*s == 'e' || *s == 'E') {
        s++;
        /* scientific notation */
        bool is_negative_exp = false;
        int exp = 0;
        int exp_count = 0;
        switch (*s) {
            case '-':
                is_negative_exp = true;
            case '+':
                s++;
        }
        while (*s >= '0' && *s <= '9') {
            exp *= 10;
            exp += (int) (*s++ - '0');
            exp_count++;
        }
        if (exp_count == 0)
            return false;
        else if (is_negative_exp)
            exp = -1 * exp;
        dval *= pow(10.0,exp);
    }
	if (is_negative)
		dval *= -1;
    remove_blanks(s);
    if (*s == 'i' || *s == 'j')
        if (is_imaginary)
            return false;
        else {
            is_imaginary = true;
            ++s;
        }
    remove_blanks(s);
	return true; 
}

bool string_to_double(const char*& s , double& real, double& imag)
{
    real = 0; imag = 0;
    double d = 0;
    bool is_imag_1 = false; bool is_imag_2 = false;
    
	if (parse_to_double(s,d,is_imag_1)) {
        if (is_imag_1)
            imag = d;
        else
            real = d;
        if (is_null_or_blank(s))
            return true;
        else if (parse_to_double(s,d,is_imag_2)) {
			if (is_imag_1 && is_imag_2)
				return false;
			else if (is_imag_2)
				imag = d;
			else
				real = d;
			return is_null_or_blank(s);
		}
		else
			return false;
    }
    else
        return false;
}

#ifdef USE_PARALLEL_ALGORITHM
// following includes if using boost
#include <vector>
#include <boost/thread/thread.hpp>
#include <boost/thread/mutex.hpp>
#include <boost/bind.hpp>
/* Following includes if using native std with C++11 features.
   Please note that the set of compilers supporting new C++ standard 
   features is (in the time of writing 09 Oct 2012) very scarce.
   So if your mex command returns compiler errors like missing 
   <thread> library, most propably your compiler does not yet
   support the new C++11 standard.
*/
//#include <functional>
//#include <thread>

static const unsigned n_threads = boost::thread::hardware_concurrency();
//static const unsigned n_threads = std::thread::hardware_concurrency();

namespace ThreadSafeMex {
	/* Matlab runtime is not thread safe by its own. Only a single 
	   thread of execution can interract with Matlab runtime in a safe
	   fashion. Otherwise the behaviour is undefined.
	   by ow
	*/
#ifdef ENSURE_THREAD_SAFE_MEX
	boost::mutex m;
	//std::mutex m;
#endif
	inline mxArray *mxGetCell(const mxArray *pm, mwIndex index) {
#ifdef ENSURE_THREAD_SAFE_MEX
		//std::lock(m);
		boost::mutex::scoped_lock lock(m);
#endif
		return ::mxGetCell(pm,index);
	}
	inline char *mxArrayToString(const mxArray *array_ptr)
	{
#ifdef ENSURE_THREAD_SAFE_MEX
		//std::lock(m);
		boost::mutex::scoped_lock lock(m);
#endif
		return ::mxArrayToString(array_ptr);
	}
	inline bool mxIsChar(const mxArray *pm)
	{
#ifdef ENSURE_THREAD_SAFE_MEX
		//std::lock(m);
		boost::mutex::scoped_lock lock(m);
#endif
		return ::mxIsChar(pm);
	}
};

void parallel_str_to_double_task(const mxArray* mxStr, 
								 double* real, double* imag, 
								 size_t job_id_start, size_t job_id_end) 
{
	mxArray *cell = 0; 
    const char *s = 0; 
    for (size_t i = job_id_start; i < job_id_end; i++) {
		cell = ThreadSafeMex::mxGetCell(mxStr,i);
		if (cell == 0 || !ThreadSafeMex::mxIsChar(cell)) {
			real[i] = NaN; 
			imag[i] = 0; 
		}
		else {
			s = ThreadSafeMex::mxArrayToString(cell);
			if(!string_to_double(s,real[i],imag[i])) {
				real[i] = NaN; 
				imag[i] = 0; 
			}
		}
	}
}
#endif

void mexFunction( int nlhs, mxArray *plhs[], 
		  int nrhs, const mxArray*prhs[] )

{
    const mxArray *mxStr = prhs[0];
    if (nrhs == 0)
		mexErrMsgTxt("Too few input arguments"); 
    else if  (nrhs > 1)
        mexErrMsgTxt("Too many input arguments."); 
	if (mxIsChar(mxStr)) {
		plhs[0] = mxCreateDoubleMatrix(1,1, mxCOMPLEX);
		const char *s = mxArrayToString(mxStr);
        double *real = mxGetPr(plhs[0]);
        double *imag = mxGetPi(plhs[0]);
		if (!string_to_double(s, 
							  real[0], 
							  imag[0])) {
			real[0] = NaN; 
			imag[0] = 0; 
		}
	}
	else if (mxIsCell(mxStr)) {
		size_t n = mxGetNumberOfElements(mxStr);
        plhs[0] = mxCreateNumericArray(mxGetNumberOfDimensions(mxStr),
                                       mxGetDimensions(mxStr),
                                       mxDOUBLE_CLASS,
                                       mxCOMPLEX);
        double *real = mxGetPr(plhs[0]);
        double *imag = mxGetPi(plhs[0]);

#ifdef USE_PARALLEL_ALGORITHM
		//using std::thread;
		//using std::bind;
		using boost::thread;
		using boost::bind;

		if (n < 1024 || n_threads <= 1) {
			// too small task to do in parallel. Just serialize
			mxArray *cell = 0; const char *s = 0;
			for (size_t i = 0; i < n; i++) {
				cell = mxGetCell(mxStr,i);
				if (cell == 0 || !mxIsChar(cell)) {
					real[i] = NaN; 
					imag[i] = 0; 
				}
				else {
					s = mxArrayToString(cell);
					if(!string_to_double(s,real[i],imag[i])) {
						real[i] = NaN; 
						imag[i] = 0; 
					}
				}
			}
			return;
		}

		const size_t grain_size = (size_t)((double)n / n_threads);
		std::vector<thread*> threads(n_threads,0);
		
		size_t job_first = 0;
		for(size_t i = 0; i < n_threads; ++i) {
			threads[i] = new thread(bind(parallel_str_to_double_task,
										 mxStr, 
										 real, 
										 imag, 
										 job_first, 
										 i < n_threads -1 ? job_first + grain_size : n));
			job_first += grain_size;
		}

		// main thread is blocked in the following loop until all works finished
		for(size_t i = 0; i < threads.size(); ++i) {
			threads[i]->join();
			delete threads[i];
		}
#else
		mxArray *cell = 0; const char *s = 0;
		for (size_t i = 0; i < n; i++) {
			cell = mxGetCell(mxStr,i);
            if (cell == 0 || !mxIsChar(cell)) {
                real[i] = NaN; 
                imag[i] = 0; 
            }
            else {
                s = mxArrayToString(cell);
                if(!string_to_double(s,real[i],imag[i])) {
                    real[i] = NaN; 
                    imag[i] = 0; 
                }
            }
		}
#endif
	}    
    else if (mxIsDouble(mxStr)) {
        if (mxIsEmpty(mxStr)) {
            plhs[0] = mxCreateDoubleScalar(NaN);
            return;
        }
        // return vector of NaN's
        size_t n = mxGetNumberOfElements(mxStr);
        plhs[0] = mxCreateNumericArray(mxGetNumberOfDimensions(mxStr),
                                       mxGetDimensions(mxStr),
                                       mxDOUBLE_CLASS,
                                       mxREAL);
        double *d = mxGetPr(plhs[0]);
        for (size_t i = 0; i < n; i++)
            d[i] = NaN;
    }
    else {
		// case to handle other situations, eg input is a class etc....
		plhs[0] = mxCreateDoubleScalar(NaN);
	}
};

