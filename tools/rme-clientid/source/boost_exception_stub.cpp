#define BOOST_NO_EXCEPTIONS
#include <boost/throw_exception.hpp>
#include <exception>

namespace boost {
    void throw_exception(std::exception const& e) {
        throw e;
    }
    void throw_exception(std::exception const& e, boost::source_location const&) {
        throw e;
    }
}
